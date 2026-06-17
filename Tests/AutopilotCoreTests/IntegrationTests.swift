import Testing
import Foundation
import ApplicationServices
@testable import AutopilotCore

@Suite struct IntegrationTests {
    /// Path to the built TestHostApp .app bundle. A bare Mach-O does not launch
    /// as a foreground GUI app with its own Accessibility tree, so the fixture is
    /// assembled into a real .app bundle by `Fixtures/TestHostApp/make-app.sh`.
    func testHostApp() -> URL {
        // Resolves relative to the package root when run via `swift test`.
        let pkgRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // AutopilotCoreTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // package root
        return pkgRoot
            .appendingPathComponent("Fixtures/TestHostApp/.build/TestHostApp.app")
    }

    /// Terminate any running TestHostApp instances (best-effort) so the test
    /// is hermetic regardless of leaked processes from earlier runs.
    func killExistingTestHostApps() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        p.arguments = ["-f", "TestHostApp.app"]
        try? p.run()
        p.waitUntilExit()
        Thread.sleep(forTimeInterval: 0.4)
    }

    @Test func typeUpdatesStatusLabel() async throws {
        guard AXIsProcessTrusted() else {
            // Skip when no AX permission; do not fail CI.
            return
        }
        let binary = testHostApp()
        guard FileManager.default.fileExists(atPath: binary.path) else {
            Issue.record("TestHostApp.app not built. Run: Fixtures/TestHostApp/make-app.sh")
            return
        }

        // Hermetic precondition: kill any leftover TestHostApp instances so a
        // leaked process from a prior run cannot poison element resolution
        // (the resolver would otherwise walk a different instance's tree).
        killExistingTestHostApps()
        defer { killExistingTestHostApps() }

        let artifacts = FileManager.default.temporaryDirectory
            .appendingPathComponent("autopilot-it-\(UUID().uuidString)")
        let plan = Plan(
            schemaVersion: "1.0",
            name: "host: type updates status",
            target: TargetApp(path: binary.path),
            defaults: PlanDefaults(timeoutMs: 4000, retryIntervalMs: 100),
            steps: [
                Step(id: "type-name", action: .type,
                     target: Selector(role: "AXTextField", identifier: "nameField"),
                     args: { var a = ActionArgs(); a.text = "Ada"; return a }()),
                Step(id: "assert-status", action: .assert,
                     target: Selector(identifier: "statusLabel"),
                     assert: Assertion(property: .value, op: .contains, expected: "Ada")),
                // Terminate so we don't leak a TestHostApp instance across runs.
                Step(id: "quit", action: .terminate),
            ]
        )
        let runner = PlanRunner()
        let report = try runner.run(plan, options: RunOptions(artifactsDir: artifacts))
        #expect(report.result == .pass, "report: \(Reporter().humanSummary(report))")
    }
}
