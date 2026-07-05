import Testing
import Foundation

/// Exercises the built `autopilot` CLI as a subprocess. Covers the headless
/// commands (no GUI/AX needed): lint, bad-path run, help, and exit codes.
/// GUI-driving commands (dump-axtree/find/suggest/run) are covered by the
/// integration tests; here we verify argument parsing, output, and exit codes.
@Suite struct CLITests {
    /// Locate the built `autopilot` binary next to the test bundle.
    static func binary() -> URL? {
        // #filePath → …/Tests/AutopilotCoreTests/CLITests.swift; the binary is
        // under .build/<config>/autopilot. Search the build dir.
        let pkgRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let build = pkgRoot.appendingPathComponent(".build")
        for config in ["debug", "release"] {
            let candidate = build.appendingPathComponent(config).appendingPathComponent("autopilot")
            if FileManager.default.isExecutableFile(atPath: candidate.path) { return candidate }
        }
        return nil
    }

    struct Result { var stdout: String; var stderr: String; var code: Int32 }

    @discardableResult
    static func run(_ args: [String], stdinText: String? = nil) throws -> Result {
        guard let bin = binary() else {
            Issue.record("autopilot binary not built; run `swift build` first")
            return Result(stdout: "", stderr: "", code: -1)
        }
        let p = Process()
        p.executableURL = bin
        p.arguments = args
        let out = Pipe(), err = Pipe()
        p.standardOutput = out; p.standardError = err
        try p.run()
        p.waitUntilExit()
        let o = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let e = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return Result(stdout: o, stderr: e, code: p.terminationStatus)
    }

    func tempFile(_ contents: String, ext: String = "json") throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("autopilot-cli-\(UUID().uuidString).\(ext)")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @Test func helpListsSubcommands() throws {
        let r = try Self.run(["--help"])
        #expect(r.stdout.contains("run") || r.stderr.contains("run"))
        #expect(r.stdout.contains("lint") || r.stderr.contains("lint"))
    }

    @Test func versionFlagPrintsVersionAndExits0() throws {
        let r = try Self.run(["--version"])
        #expect(r.code == 0)
        // Prints the product name + a semver, and does NOT error as a missing
        // plan path (the pre-fix behavior routed --version to the default `run`).
        let out = r.stdout + r.stderr
        #expect(out.contains("AutoPilot"))
        #expect(out.range(of: #"\d+\.\d+\.\d+"#, options: .regularExpression) != nil)
        #expect(!out.contains("Missing expected argument"))
    }

    @Test func runBadPathExits2() throws {
        let r = try Self.run(["run", "/definitely/not/a/plan.json"])
        #expect(r.code == 2)
        #expect(r.stderr.contains("Cannot read plan"))
    }

    @Test func runUnsupportedKeyExits4() throws {
        // A keyPress chord with an unsupported final key gets exit 4 (distinct from
        // 2 = invalid plan), so a harness can triage "key not supported yet".
        let plan = """
        {"schemaVersion":"1.1","name":"badkey","target":{"bundleId":"a"},
         "steps":[{"id":"k","level":"happyPath","action":"keyPress",
                   "target":{"role":"AXWindow"},"args":{"keys":"cmd+£"}}]}
        """
        let url = try tempFile(plan)
        let r = try Self.run(["run", url.path])
        #expect(r.code == 4)
        #expect(r.stderr.lowercased().contains("key"))
    }

    @Test func runInvalidPlanExits2() throws {
        // A malformed plan (not a key problem) stays exit 2.
        let url = try tempFile(#"{"not":"a plan"}"#)
        let r = try Self.run(["run", url.path])
        #expect(r.code == 2)
    }

    @Test func lintCleanPlanExits0() throws {
        let plan = """
        {"schemaVersion":"1.1","name":"ok","target":{"bundleId":"a"},
         "steps":[
           {"id":"w","level":"happyPath","action":"waitFor","target":{"role":"AXWindow"},"args":{"present":true}},
           {"id":"c","level":"happyPath","action":"click","target":{"identifier":"ok"}},
           {"id":"q","level":"happyPath","action":"terminate"}
         ]}
        """
        let url = try tempFile(plan)
        let r = try Self.run(["lint", url.path])
        #expect(r.code == 0)
        #expect(r.stdout.contains("ok"))
    }

    @Test func lintFlagsProblemsAndExits1() throws {
        let plan = """
        {"schemaVersion":"1.1","name":"bad","target":{"bundleId":"a"},
         "steps":[{"id":"c","level":"happyPath","action":"click","target":{"label":"x"}}]}
        """
        let url = try tempFile(plan)
        let r = try Self.run(["lint", url.path])
        #expect(r.code == 1)
        #expect(r.stdout.contains("label"))
    }

    @Test func lintInvalidJsonReportsError() throws {
        let url = try tempFile("{ not json")
        let r = try Self.run(["lint", url.path])
        #expect(r.code == 1)
        #expect(r.stdout.contains("ERROR") || r.stdout.contains("error"))
    }
}
