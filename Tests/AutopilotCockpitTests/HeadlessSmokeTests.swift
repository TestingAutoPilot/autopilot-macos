import Testing
@testable import AutopilotCockpit
import AutopilotCore

/// A CI-safe smoke test: exercises the cockpit's pure logic end-to-end with a
/// FakeDriver, no WindowServer. Proves the whole target links + the engine/
/// controller/editor cooperate. The live-GUI path is verified manually on a real
/// display (see the plan's Verification section), NOT in hosted CI.
@MainActor
@Suite struct HeadlessSmokeTests {
    @Test func inspectToAuthorHandoffPurePath() {
        let engine = CockpitEngine(driver: FakeDriver(nodes: [
            ["role": "AXWindow", "frame": "0,0,100,100"],
            ["role": "AXButton", "identifier": "ok", "frame": "10,10,20,20"],
        ]))
        engine.attach(pid: 7); engine.refreshTree()
        let button = engine.roots.first?.children.first
        #expect(button?.identifier == "ok")
        engine.pendingSelector = engine.selector(for: button!)

        let editor = PlanEditor(plan: Plan(schemaVersion: "1.1", name: "smoke",
            target: TargetApp(bundleId: "com.example"), steps: []))
        editor.addStep(action: .click, level: .happyPath)
        editor.setSelector(engine.pendingSelector!, forStepAt: 0)
        #expect(editor.plan.steps[0].target?.identifier == "ok")
    }
}
