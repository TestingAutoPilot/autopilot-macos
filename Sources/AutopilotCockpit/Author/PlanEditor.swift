import Foundation
import Observation
import AutopilotCore

/// A mutable, observable wrapper around a Plan for the Author panel. Edits stay
/// schema-valid because they mutate the Codable Plan model directly; save
/// re-encodes that model.
@Observable
final class PlanEditor {
    var plan: Plan

    init(plan: Plan) { self.plan = plan }

    /// Append a new step with a generated unique id.
    func addStep(action: Action, level: StepLevel) {
        let id = nextId()
        plan.steps.append(Step(id: id, action: action, level: level))
    }

    func deleteStep(at offsets: IndexSet) {
        plan.steps.remove(atOffsets: offsets)
    }

    func moveStep(from offsets: IndexSet, to destination: Int) {
        plan.steps.move(fromOffsets: offsets, toOffset: destination)
    }

    func setSelector(_ selector: AutopilotCore.Selector, forStepAt index: Int) {
        guard plan.steps.indices.contains(index) else { return }
        plan.steps[index].target = selector
    }

    func setLevel(_ level: StepLevel, forStepAt index: Int) {
        guard plan.steps.indices.contains(index) else { return }
        plan.steps[index].level = level
    }

    /// Pretty, sorted-keys JSON of the current plan.
    func encoded() throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try enc.encode(plan)
    }

    /// A unique step id like "step-N" not already used.
    private func nextId() -> String {
        let used = Set(plan.steps.map(\.id))
        var n = plan.steps.count + 1
        while used.contains("step-\(n)") { n += 1 }
        return "step-\(n)"
    }
}
