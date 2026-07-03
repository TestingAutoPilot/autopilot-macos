import Testing
import Foundation
@testable import AutopilotCockpit
import AutopilotCore

@Suite struct PlanEditorTests {
    private func base() -> Plan {
        Plan(schemaVersion: "1.1", name: "edit-demo",
             target: TargetApp(bundleId: "com.example"),
             steps: [Step(id: "s1", action: .launch, level: .happyPath)])
    }

    @Test func addAndDeleteSteps() {
        let e = PlanEditor(plan: base())
        e.addStep(action: .click, level: .happyPath)
        #expect(e.plan.steps.count == 2)
        e.deleteStep(at: IndexSet(integer: 1))
        #expect(e.plan.steps.count == 1)
    }

    @Test func setSelectorOnStep() {
        let e = PlanEditor(plan: base())
        e.addStep(action: .click, level: .happyPath)
        e.setSelector(AutopilotCore.Selector(identifier: "ok"), forStepAt: 1)
        #expect(e.plan.steps[1].target?.identifier == "ok")
    }

    @Test func roundTripsThroughParser() throws {
        let e = PlanEditor(plan: base())
        e.addStep(action: .click, level: .integrationSuite)
        e.setSelector(AutopilotCore.Selector(identifier: "go"), forStepAt: 1)
        let data = try e.encoded()
        let reparsed = try PlanParser().parse(data: data, baseDirectory: FileManager.default.temporaryDirectory)
        #expect(reparsed == e.plan)
    }
}
