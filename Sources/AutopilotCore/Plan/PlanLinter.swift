import Foundation

/// Static analysis of a plan beyond schema validity — flags the documented
/// footguns so authors catch them before a run.
public struct PlanLinter {
    public enum Severity: String, Sendable { case warning, error }
    public struct Finding: Sendable, Equatable {
        public var severity: Severity
        public var stepId: String?
        public var message: String
    }

    public init() {}

    /// Lint a (already schema-valid) plan. Returns findings in document order.
    public func lint(_ plan: Plan) -> [Finding] {
        var findings: [Finding] = []

        // Non-functional selector fields (documented as not working).
        for step in plan.steps {
            if let sel = step.target {
                if sel.label != nil {
                    findings.append(.init(severity: .warning, stepId: step.id,
                        message: "selector uses `label`, which is non-functional — use `identifier`, `title`, or `value`"))
                }
                if sel.path != nil {
                    findings.append(.init(severity: .warning, stepId: step.id,
                        message: "selector uses `path`, which is non-functional — it is silently ignored"))
                }
            }
        }

        // Missing terminate as the last step → leaks an app instance.
        if let last = plan.steps.last, last.action != .terminate {
            findings.append(.init(severity: .warning, stepId: nil,
                message: "plan does not end with a `terminate` step — the app will be left running"))
        }

        // No window wait before the first input/assert step.
        let inputActions: Set<Action> = [.click, .doubleClick, .rightClick, .press,
                                         .type, .keyPress, .setValue, .scroll, .drag, .menu]
        if let firstInputIdx = plan.steps.firstIndex(where: { inputActions.contains($0.action) }) {
            let waitsBefore = plan.steps[..<firstInputIdx].contains {
                $0.action == .waitFor && $0.target?.role == "AXWindow"
            }
            if !waitsBefore {
                findings.append(.init(severity: .warning, stepId: plan.steps[firstInputIdx].id,
                    message: "no `waitFor` on an AXWindow before the first input step — the app may not be ready"))
            }
        }

        return findings
    }
}
