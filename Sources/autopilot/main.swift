import Foundation
import ApplicationServices
import ArgumentParser
import AutopilotCore
import MacOSDriver

/// The released AutoPilot version. Bumped in the same change set as a release tag
/// (there is no separate VERSION file). Reported by `autopilot --version`.
let autopilotVersion = "3.2.1"

struct Autopilot: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "autopilot",
        abstract: "Run a declarative GUI test plan against a macOS app.",
        version: "AutoPilot \(autopilotVersion)",
        subcommands: [Run.self, Doctor.self, DumpAxtree.self, Lint.self, Find.self, Suggest.self, MenuList.self, DismissAlert.self, Docs.self],
        defaultSubcommand: Run.self
    )
}

/// Locates the installed documentation directory. Docs ship next to the binary
/// so a `brew`-installed AutoPilot carries its own manual, not just the CLI.
///
/// Search order (first that exists wins):
///   1. `$AUTOPILOT_DOCS` (explicit override — tests, unusual layouts).
///   2. `<bin>/../share/doc/autopilot` — the Homebrew `doc.install` location
///      (`/opt/homebrew/Cellar/autopilot/<v>/share/doc/autopilot`, with `bin`
///      the Cellar's `bin`). This is where a `brew` install puts them.
///   3. `<bin>/../docs` and `<bin>/docs` — a plain tarball / dev layout.
///   4. The source-tree `docs/` walked up from `<bin>` (`swift run` from a
///      checkout, where the binary sits in `.build/…`).
enum DocsLocator {
    /// Candidate directories, in priority order, for the given running-binary
    /// path and environment. Pure/injected so it is testable without touching
    /// the real process. Does NOT check the filesystem — the caller picks the
    /// first that exists (or the first, as a best-effort message target).
    static func candidates(binaryURL: URL, env: [String: String]) -> [URL] {
        var dirs: [URL] = []
        if let override = env["AUTOPILOT_DOCS"], !override.isEmpty {
            dirs.append(URL(fileURLWithPath: override))
        }
        let bin = binaryURL.resolvingSymlinksInPath()
        let binDir = bin.deletingLastPathComponent()          // …/bin
        let prefix = binDir.deletingLastPathComponent()       // …/<cellar version>
        dirs.append(prefix.appendingPathComponent("share/doc/autopilot"))
        dirs.append(prefix.appendingPathComponent("docs"))
        dirs.append(binDir.appendingPathComponent("docs"))
        // Walk up from the binary looking for a source-tree docs/ (dev builds
        // live at <root>/.build/<triple>/<config>/autopilot).
        var up = binDir
        for _ in 0..<6 {
            up = up.deletingLastPathComponent()
            dirs.append(up.appendingPathComponent("docs"))
        }
        return dirs
    }

    /// The resolved docs directory (first candidate that exists), or nil.
    static func resolve(fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }) -> URL? {
        let bin = FileDragSource.runningBinaryURL()
        for dir in candidates(binaryURL: bin, env: ProcessInfo.processInfo.environment) {
            if fileExists(dir.path) { return dir }
        }
        return nil
    }
}

/// The documents AutoPilot ships, in menu order. `key` is what the user types
/// (`autopilot docs manual`); `file` is the on-disk name in the docs dir.
private let shippedDocs: [(key: String, file: String, blurb: String)] = [
    ("manual",    "MANUAL.md",    "Full user manual — actions, selectors, running plans"),
    ("authoring", "AUTHORING.md", "How to write a test plan (selectors, steps, assertions)"),
    ("readme",    "README.md",    "Overview and quick start"),
    ("roadmap",   "ROADMAP.md",   "Planned features and direction"),
    ("ci",        "CI.md",        "CI & distribution notes"),
]

struct Docs: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "docs",
        abstract: "Print AutoPilot's bundled documentation (manual, authoring guide, …).")

    @Argument(help: "Which doc to print (manual, authoring, readme, roadmap, ci). Omit to list.")
    var name: String?

    @Flag(name: .long, help: "Open the doc in your default handler instead of printing it.")
    var open: Bool = false

    func run() throws {
        guard let dir = DocsLocator.resolve() else {
            let msg = "No documentation found. Docs ship alongside the binary (share/doc/autopilot); "
                + "for a Homebrew install see `brew --prefix autopilot`. "
                + "Set AUTOPILOT_DOCS to a docs directory to override.\n"
            FileHandle.standardError.write(Data(msg.utf8))
            throw ExitCode(2)
        }

        guard let name else {
            print("AutoPilot documentation (in \(dir.path)):\n")
            for d in shippedDocs where FileManager.default.fileExists(atPath: dir.appendingPathComponent(d.file).path) {
                print("  \(d.key.padding(toLength: 10, withPad: " ", startingAt: 0)) \(d.blurb)")
            }
            print("\nRun `autopilot docs <name>` to print one, or add --open to open it.")
            return
        }

        let key = name.lowercased()
        guard let entry = shippedDocs.first(where: { $0.key == key }) else {
            FileHandle.standardError.write(Data(
                "Unknown doc \"\(name)\". Known: \(shippedDocs.map(\.key).joined(separator: ", ")).\n".utf8))
            throw ExitCode(2)
        }
        let file = dir.appendingPathComponent(entry.file)
        guard FileManager.default.fileExists(atPath: file.path) else {
            FileHandle.standardError.write(Data(
                "\(entry.file) is not installed at \(dir.path).\n".utf8))
            throw ExitCode(2)
        }

        if open {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            p.arguments = [file.path]
            try p.run(); p.waitUntilExit()
            if p.terminationStatus != 0 { throw ExitCode(p.terminationStatus) }
            return
        }

        let text = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
        FileHandle.standardOutput.write(Data(text.utf8))
    }
}

/// Shared helper for inspection commands (dump-axtree/find/suggest): ATTACH to a
/// running instance (never launch/terminate). Resolves by --pid first, else by
/// the bundleId/path argument → frontmost running instance.
enum Inspect {
    static func attach(app appArg: String?, pid: Int32?) throws -> LaunchedApp {
        guard Permissions().hasAccessibility() else {
            FileHandle.standardError.write(Data("Accessibility permission required (run: autopilot doctor)\n".utf8))
            throw ExitCode(3)
        }
        do {
            if let pid { return try AppLauncher().attach(pid: pid_t(pid)) }
            guard let appArg else {
                FileHandle.standardError.write(Data("Provide an app (bundle id or .app path) or --pid.\n".utf8))
                throw ExitCode(2)
            }
            let target: TargetApp = appArg.hasSuffix(".app") || appArg.hasPrefix("/")
                ? TargetApp(path: appArg) : TargetApp(bundleId: appArg)
            return try AppLauncher().attach(target)
        } catch let e as AppLaunchError {
            FileHandle.standardError.write(Data("\(e)\n".utf8))
            throw ExitCode(2)
        }
    }

    /// Wait briefly for the AX tree to be queryable, then return the app element.
    static func appElement(_ launched: LaunchedApp) -> AXUIElement {
        let el = AXTree.application(pid: launched.pid)
        _ = Targeting().waitForPresence(Selector(role: "AXWindow"), present: true,
                                        app: el, timeoutMs: 2000, intervalMs: 100)
        return el
    }
}

struct Suggest: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "suggest",
        abstract: "Attach to a RUNNING app and suggest a selector for each interactive element.")

    @Argument(help: "Bundle id or path to a .app bundle (of the running app).")
    var app: String?

    @Option(name: .long, help: "Attach to a specific running process by pid (unambiguous).")
    var pid: Int32?

    func run() throws {
        let launched = try Inspect.attach(app: app, pid: pid)   // attach, never launch
        let appEl = Inspect.appElement(launched)
        let snap = AXTree.snapshot(appEl)
        let suggestions = SelectorSuggester.suggest(from: snap.nodes)
        for s in suggestions {
            let sel = (try? String(data: JSONEncoder.pretty.encode(s.selector), encoding: .utf8)) ?? ""
            let oneLine = sel.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "  ", with: " ")
            let label = s.label.isEmpty ? "" : "  “\(s.label)”"
            print("\(s.role)\(label)\n    \(oneLine)\n    # \(s.note)")
        }
    }
}

struct MenuList: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "menu",
        abstract: "Attach to a RUNNING app and list a menu's items (including disabled ones).")

    @Argument(help: "Bundle id or path to a .app bundle (of the running app).")
    var app: String?

    @Option(name: .long, help: "Attach to a specific running process by pid (unambiguous).")
    var pid: Int32?

    @Option(name: .long, parsing: .upToNextOption,
            help: "Menu title path to list, e.g. --path View  or  --path Edit Text. Empty = top-level menu titles.")
    var path: [String] = []

    func run() throws {
        let launched = try Inspect.attach(app: app, pid: pid)   // attach, never launch
        let appEl = Inspect.appElement(launched)
        let items = try MenuNavigator().listItems(path: path, app: appEl)
        let payload: [String: Any] = [
            "pid": launched.pid,
            "appName": launched.runningApp.localizedName ?? "",
            "path": path,
            "items": items.map { item -> [String: Any] in
                var d: [String: Any] = ["title": item.title, "enabled": item.enabled, "hasSubmenu": item.hasSubmenu]
                if let m = item.markChar { d["markChar"] = m }
                return d
            },
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }
}

struct DismissAlert: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dismiss-alert",
        abstract: "Press a button in ANOTHER process's alert/dialog by attaching to its pid — "
                + "e.g. a LaunchServices permission alert owned by CoreServicesUIAgent, which a "
                + "target-attached run cannot see.")

    @Argument(help: "Bundle id or path of the alert-owning app (e.g. com.apple.coreservices.uiagent).")
    var app: String?

    @Option(name: .long, help: "Attach to a specific process by pid (the alert's owner).")
    var pid: Int32?

    @Option(name: .long, help: "Button title to press. If omitted, tries OK / Close / Cancel / Don't Save.")
    var button: String?

    func run() throws {
        let launched = try Inspect.attach(app: app, pid: pid)   // attach to the alert's OWNER
        let appEl = AXTree.application(pid: launched.pid)
        let resolver = MacAXResolver()
        let candidates = button.map { [$0] } ?? ["OK", "Close", "Cancel", "Don’t Save", "Don't Save", "Dismiss"]
        for title in candidates {
            let selector = AutopilotCore.Selector(role: "AXButton", title: title)
            if let el = try? resolver.resolveOne(in: appEl, selector: selector) {
                if AXTree.press(el) {
                    print("pressed “\(title)” in \(launched.runningApp.localizedName ?? "pid \(launched.pid)")")
                    return
                }
                FileHandle.standardError.write(Data("found “\(title)” but AXPress failed\n".utf8))
                throw ExitCode(1)
            }
        }
        let tried = candidates.joined(separator: ", ")
        FileHandle.standardError.write(Data("No matching button found (tried: \(tried)).\n".utf8))
        throw ExitCode(1)
    }
}

struct DumpAxtree: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dump-axtree",
        abstract: "Attach to a RUNNING app and print its accessibility tree (for authoring selectors).")

    @Argument(help: "Bundle id (com.example.app) or a path to a .app bundle (of the running app).")
    var app: String?

    @Option(name: .long, help: "Attach to a specific running process by pid (unambiguous).")
    var pid: Int32?

    @Flag(name: .long, help: "Only include interactive elements (buttons, fields, rows, …).")
    var interactiveOnly: Bool = false

    @Flag(name: .long, help: "Drop the menu bar and menu items (usually noise for authoring).")
    var omitMenubar: Bool = false

    @Option(name: .long, help: "Only include nodes inside the first element of this role (e.g. AXWindow).")
    var underRole: String?

    func run() throws {
        let launched = try Inspect.attach(app: app, pid: pid)   // attach, never launch
        let appEl = Inspect.appElement(launched)
        let snap = AXTree.snapshot(appEl)
        var nodes = interactiveOnly ? snap.nodes.filter { AXRoles.isInteractive($0["role"]) } : snap.nodes
        if let role = underRole { nodes = TreeFilter.underRole(role, nodes) }
        if omitMenubar { nodes = TreeFilter.omitMenuBar(nodes) }
        let payload: [String: Any] = [
            "pid": launched.pid,
            "appName": launched.runningApp.localizedName ?? "",
            "truncated": snap.truncated, "nodeCount": nodes.count, "nodes": nodes,
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }
}

struct Lint: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "lint",
        abstract: "Statically check a plan (or a directory of plans) for common mistakes.")

    @Argument(help: "Path to a plan .json file or a directory of plans.")
    var path: String

    func run() throws {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else {
            FileHandle.standardError.write(Data("Not found: \(path)\n".utf8)); throw ExitCode(2)
        }
        let urls = isDir.boolValue
            ? Run.discoverPlans(in: URL(fileURLWithPath: path))
            : [URL(fileURLWithPath: path)]
        var anyFindings = false
        for url in urls {
            guard let data = try? Data(contentsOf: url) else { continue }
            let plan: Plan
            do { plan = try PlanParser().parse(data: data, baseDirectory: url.deletingLastPathComponent()) }
            catch {
                print("\(url.lastPathComponent): ERROR \(error)")
                anyFindings = true; continue
            }
            let findings = PlanLinter().lint(plan)
            if findings.isEmpty {
                print("\(url.lastPathComponent): ok")
            } else {
                anyFindings = true
                for f in findings {
                    let loc = f.stepId.map { " [\($0)]" } ?? ""
                    print("\(url.lastPathComponent):\(loc) \(f.severity.rawValue): \(f.message)")
                }
            }
        }
        if anyFindings { throw ExitCode(1) }
    }
}

struct Find: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "find",
        abstract: "Attach to a RUNNING app and show which elements a selector resolves to.")

    @Argument(help: "Bundle id or path to a .app bundle (of the running app).")
    var app: String?

    @Option(name: .long, help: "Attach to a specific running process by pid (unambiguous).")
    var pid: Int32?

    @Option(name: .long, help: "AX role to match, e.g. AXButton.")
    var role: String?
    @Option(name: .long, help: "AX identifier to match.")
    var identifier: String?
    @Option(name: .long, help: "AX title to match.")
    var title: String?

    func run() throws {
        let launched = try Inspect.attach(app: app, pid: pid)   // attach, never launch
        let appEl = Inspect.appElement(launched)
        let selector = Selector(role: role, identifier: identifier, title: title)
        let matches = MacAXResolver().findAll(in: appEl, selector: selector)
        print("\(matches.count) match(es) for \(AXResolver.describe(selector)):")
        for m in matches { print("  \(m)") }
        if matches.count != 1 { throw ExitCode(1) }
    }
}

struct Run: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Execute a plan JSON file.")

    @Argument(help: "Path to the plan JSON file.")
    var planPath: String

    @Option(name: .long, help: "Directory for report.json and failure artifacts.")
    var artifacts: String = "artifacts"

    @Flag(name: .long, help: "Continue after a failing step instead of stopping.")
    var keepGoing: Bool = false

    @Flag(name: .long, help: "Write/overwrite snapshot reference images (otherwise a missing reference fails).")
    var updateSnapshots: Bool = false

    @Flag(name: .long, help: "Print report.json to stdout instead of the human summary.")
    var json: Bool = false

    func run() throws {
        let url = URL(fileURLWithPath: planPath)
        let artifactsURL = URL(fileURLWithPath: artifacts)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else {
            FileHandle.standardError.write(Data("Cannot read plan: \(planPath)\n".utf8)); throw ExitCode(2)
        }
        if isDir.boolValue {
            try runSuite(dir: url, artifactsURL: artifactsURL)
        } else {
            try runSingle(planURL: url, artifactsURL: artifactsURL)
        }
    }

    private func runSingle(planURL: URL, artifactsURL: URL) throws {
        let baseDir = planURL.deletingLastPathComponent()
        let data: Data
        do { data = try Data(contentsOf: planURL) }
        catch { FileHandle.standardError.write(Data("Cannot read plan: \(planURL.path)\n".utf8)); throw ExitCode(2) }

        let plan: Plan
        do { plan = try PlanParser().parse(data: data, baseDirectory: baseDir) }
        catch {
            FileHandle.standardError.write(Data("Plan error: \(error)\n".utf8))
            throw Self.parseExitCode(for: error)
        }

        let report = try PlanRunner(driver: MacOSDriver()).run(plan, options: RunOptions(
            keepGoing: keepGoing, artifactsDir: artifactsURL, planBaseDir: baseDir,
            updateSnapshots: updateSnapshots))
        let reporter = Reporter()
        if json {
            FileHandle.standardOutput.write(try reporter.json(report))
            FileHandle.standardOutput.write(Data("\n".utf8))
        } else {
            print(reporter.humanSummary(report))
        }
        FileHandle.standardError.write(Data((reporter.summaryLine(report) + "\n").utf8))

        if report.permissions?.accessibility == false { throw ExitCode(3) }
        switch report.result {
        case .pass, .skipped: return
        case .fail, .error: throw ExitCode(1)
        }
    }

    /// Run every *.json plan in `dir` (recursively, sorted) sequentially.
    /// Plans MUST run one at a time: macOS has a single keyboard/mouse focus,
    /// so input-driving plans cannot run in parallel without fighting over it.
    private func runSuite(dir: URL, artifactsURL: URL) throws {
        let planURLs = Self.discoverPlans(in: dir)
        guard !planURLs.isEmpty else {
            FileHandle.standardError.write(Data("No .json plans found under: \(dir.path)\n".utf8))
            throw ExitCode(2)
        }
        var reports: [Report] = []
        var permMissing = false
        for planURL in planURLs {
            let baseDir = planURL.deletingLastPathComponent()
            let name = planURL.lastPathComponent
            // An unreadable/invalid plan is an ERROR, not a silent skip — else a
            // suite of all-broken plans would report SUITE pass 0/0 and exit 0.
            guard let data = try? Data(contentsOf: planURL) else {
                reports.append(Self.errorReport(name, "could not read plan file"))
                FileHandle.standardError.write(Data("  [error] \(name): unreadable\n".utf8)); continue
            }
            let plan: Plan
            do { plan = try PlanParser().parse(data: data, baseDirectory: baseDir) }
            catch {
                reports.append(Self.errorReport(name, "invalid plan: \(error)"))
                FileHandle.standardError.write(Data("  [error] \(name): invalid (\(error))\n".utf8)); continue
            }
            // A thrown launch (or other) error for ONE plan must not abort the
            // whole suite — record it as an error report and keep going so the
            // remaining plans run and suite.json is always written.
            let report: Report
            do {
                report = try PlanRunner(driver: MacOSDriver()).run(plan, options: RunOptions(
                    keepGoing: keepGoing, artifactsDir: artifactsURL, planBaseDir: baseDir,
                    updateSnapshots: updateSnapshots))
            } catch {
                report = Self.errorReport(plan.name, "run failed: \(error)")
            }
            if report.permissions?.accessibility == false { permMissing = true }
            reports.append(report)
            FileHandle.standardError.write(Data("  [\(report.result.rawValue)] \(report.plan)\n".utf8))
        }
        let suite = SuiteReport(reports: reports)
        // Write the aggregate suite report next to the per-plan artifact dirs.
        if let suiteData = try? JSONEncoder.pretty.encode(suite) {
            try? FileManager.default.createDirectory(at: artifactsURL, withIntermediateDirectories: true)
            try? suiteData.write(to: artifactsURL.appendingPathComponent("suite.json"))
        }
        if json {
            FileHandle.standardOutput.write((try? JSONEncoder.pretty.encode(suite)) ?? Data())
            FileHandle.standardOutput.write(Data("\n".utf8))
        } else {
            print(suite.humanSummary())
        }
        FileHandle.standardError.write(Data((suite.summaryLine() + "\n").utf8))

        if permMissing { throw ExitCode(3) }
        switch suite.result {
        case .pass, .skipped: return
        case .fail, .error: throw ExitCode(1)
        }
    }

    /// Map a plan-parse error to an exit code. An **unsupported key chord** gets
    /// its own code (4) so a harness can distinguish "this key isn't supported yet"
    /// from a malformed/invalid plan (2) — the report asked for this triage signal.
    /// Exit codes: 0 ok · 1 test failed · 2 invalid plan · 3 no Accessibility · 4 unsupported key.
    static func parseExitCode(for error: any Error) -> ExitCode {
        if case PlanError.unsupportedKey = error { return ExitCode(4) }
        return ExitCode(2)
    }

    /// A synthetic error Report for a plan that couldn't be read/parsed/run, so
    /// the suite aggregate counts it (and exits non-zero) instead of skipping it.
    static func errorReport(_ name: String, _ message: String) -> Report {
        var r = Report(plan: name)
        r.add(StepResult(id: "_plan", result: .error, durationMs: 0, message: message))
        r.finalize(permissions: PermissionStatus(accessibility: true, screenRecording: true))
        return r
    }

    /// All *.json plan files under `dir`, recursively, in stable sorted order.
    /// Files under a `setups/` directory are treated as include-only fragments
    /// (not standalone plans) and skipped — a common suite convention.
    static func discoverPlans(in dir: URL) -> [URL] {
        let fm = FileManager.default
        guard let en = fm.enumerator(at: dir, includingPropertiesForKeys: nil) else { return [] }
        var out: [URL] = []
        for case let u as URL in en where u.pathExtension == "json" {
            if u.pathComponents.contains("setups") { continue }
            out.append(u)
        }
        return out.sorted { $0.path < $1.path }
    }
}

extension JSONEncoder {
    static var pretty: JSONEncoder {
        let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]; return e
    }
}

struct Doctor: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Check required permissions.")
    func run() throws {
        let perms = Permissions()
        var missing = false
        if perms.hasAccessibility() {
            print("Accessibility:    OK")
        } else {
            print("Accessibility:    MISSING")
            print(perms.accessibilityInstructions())
            missing = true
        }
        // Screen Recording is required for visual actions. Report it but don't
        // make it fatal on its own — many plans don't use visual assertions.
        if perms.hasScreenRecording() {
            print("Screen Recording: OK")
        } else {
            print("Screen Recording: MISSING (needed only for assertPixel/assertRegion/snapshot/screenshot)")
            print(perms.screenRecordingInstructions())
        }
        if missing { throw ExitCode(3) }
    }
}

Autopilot.main()
