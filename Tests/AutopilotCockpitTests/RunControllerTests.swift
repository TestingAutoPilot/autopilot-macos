import Testing
import Foundation
@testable import AutopilotCockpit
import AutopilotCore

@MainActor
@Suite struct RunControllerTests {
    private func loaded() -> LoadedPlan {
        let plan = Plan(schemaVersion: "1.1", name: "run-demo",
                        target: TargetApp(bundleId: "com.fake"),
                        steps: [
                            Step(id: "s1", action: .launch, level: .happyPath),
                            Step(id: "s2", action: .wait, level: .happyPath),
                        ])
        return LoadedPlan(plan: plan, baseDir: FileManager.default.temporaryDirectory, findings: [])
    }

    @Test func seedsRowsPendingThenCompletes() async {
        let controller = RunController()
        let driver = FakeDriver(nodes: [["role": "AXWindow"]])
        controller.run(loaded(), driver: driver, maxLevel: .tryToBreakIt, keepGoing: true)
        // Wait for the background run to finish (bounded poll — no fixed sleep).
        var waited = 0
        while controller.isRunning && waited < 5000 {
            try? await Task.sleep(for: .milliseconds(50)); waited += 50
        }
        #expect(controller.isRunning == false)
        #expect(controller.rows.map(\.id) == ["s1", "s2"])
        #expect(controller.rows.allSatisfy { $0.state == .pass })
        #expect(controller.report?.plan == "run-demo")
    }
}
