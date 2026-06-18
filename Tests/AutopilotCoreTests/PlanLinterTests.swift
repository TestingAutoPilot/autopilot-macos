import Testing
import Foundation
@testable import AutopilotCore

@Suite struct PlanLinterTests {
    func plan(_ steps: [Step], include: [String]? = nil) -> Plan {
        Plan(schemaVersion: "1.0", name: "p", include: include,
             target: TargetApp(bundleId: "a"), steps: steps)
    }

    @Test func flagsLabelAndPathSelectors() {
        let p = plan([
            Step(id: "a", action: .click, target: Selector(label: "x")),
            Step(id: "b", action: .click, target: Selector(path: ["w[0]"])),
            Step(id: "z", action: .terminate),
        ])
        let f = PlanLinter().lint(p)
        #expect(f.contains { $0.message.contains("`label`") && $0.stepId == "a" })
        #expect(f.contains { $0.message.contains("`path`") && $0.stepId == "b" })
    }

    @Test func flagsMissingTerminate() {
        let p = plan([Step(id: "a", action: .screenshot)])
        #expect(PlanLinter().lint(p).contains { $0.message.contains("terminate") })
    }

    @Test func flagsMissingWindowWait() {
        let p = plan([
            Step(id: "click", action: .click, target: Selector(identifier: "ok")),
            Step(id: "q", action: .terminate),
        ])
        #expect(PlanLinter().lint(p).contains { $0.message.contains("waitFor") })
    }

    @Test func cleanPlanHasNoFindings() {
        let waitArgs = { var a = ActionArgs(); a.present = true; return a }()
        let p = plan([
            Step(id: "w", action: .waitFor, target: Selector(role: "AXWindow"), args: waitArgs),
            Step(id: "click", action: .click, target: Selector(identifier: "ok")),
            Step(id: "q", action: .terminate),
        ])
        #expect(PlanLinter().lint(p).isEmpty)
    }
}
