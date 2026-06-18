import Foundation
import ArgumentParser
import AutopilotCore

struct Autopilot: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "autopilot",
        abstract: "Run a declarative GUI test plan against a macOS app.",
        subcommands: [Run.self, Doctor.self],
        defaultSubcommand: Run.self
    )
}

struct Run: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Execute a plan JSON file.")

    @Argument(help: "Path to the plan JSON file.")
    var planPath: String

    @Option(name: .long, help: "Directory for report.json and failure artifacts.")
    var artifacts: String = "artifacts"

    @Flag(name: .long, help: "Continue after a failing step instead of stopping.")
    var keepGoing: Bool = false

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
            throw ExitCode(2)
        }

        let report = try PlanRunner().run(plan, options: RunOptions(
            keepGoing: keepGoing, artifactsDir: artifactsURL, planBaseDir: baseDir))
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
            guard let data = try? Data(contentsOf: planURL),
                  let plan = try? PlanParser().parse(data: data, baseDirectory: baseDir) else {
                FileHandle.standardError.write(Data("  skipped (invalid): \(planURL.lastPathComponent)\n".utf8))
                continue
            }
            let report = try PlanRunner().run(plan, options: RunOptions(
                keepGoing: keepGoing, artifactsDir: artifactsURL, planBaseDir: baseDir))
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
        if perms.hasAccessibility() {
            print("Accessibility: OK")
        } else {
            print("Accessibility: MISSING")
            print(perms.accessibilityInstructions())
            throw ExitCode(3)
        }
    }
}

Autopilot.main()
