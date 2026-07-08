import SwiftUI
import AutopilotCore

/// Per-step editor: the "full per-action visual editing" the Author panel previously
/// lacked. Edits the selected step's id / action / level / args / assert through the
/// PlanEditor's mutators, showing only the arg fields relevant to the chosen action.
struct StepDetailView: View {
    @Bindable var editor: PlanEditor
    let index: Int

    /// Actions offered in the per-step action picker (same curated set as the palette).
    private let actions: [Action] = [
        .click, .doubleClick, .rightClick, .press, .type, .keyPress, .setValue,
        .scroll, .menu, .drag, .assert, .waitFor, .screenshot, .launch, .terminate,
        .wait, .exec, .highlight, .caption, .pace,
    ]

    private var step: Step? { editor.plan.steps.indices.contains(index) ? editor.plan.steps[index] : nil }

    var body: some View {
        if let step {
            Form {
                Section("Step") {
                    TextField("id", text: bindId)
                    Picker("action", selection: bindAction) {
                        ForEach(actions, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    Picker("level", selection: bindLevel) {
                        Text("happyPath").tag(StepLevel.happyPath)
                        Text("integrationSuite").tag(StepLevel.integrationSuite)
                        Text("tryToBreakIt").tag(StepLevel.tryToBreakIt)
                    }
                }

                if let targetLabel = step.target.map(selectorLabel) {
                    Section("Target") {
                        Text(targetLabel).foregroundStyle(.secondary)
                        Text("Use “Apply Selector from Inspect” to set/replace.").font(.caption).foregroundStyle(.secondary)
                    }
                }

                argsSection(for: step.action)

                if step.action == .assert {
                    assertSection(step)
                }
            }
            .formStyle(.grouped)
        } else {
            ContentUnavailableView("No step selected", systemImage: "list.bullet",
                description: Text("Select a step to edit its details."))
        }
    }

    // MARK: - Args (only the fields relevant to the action)

    @ViewBuilder
    private func argsSection(for action: Action) -> some View {
        switch action {
        case .type, .setValue:
            Section("Args") {
                TextField("text", text: strArg(\.text))
                if action == .type {
                    Toggle("clear first", isOn: boolArg(\.clear))
                    Toggle("commit (press Return)", isOn: boolArg(\.commit))
                }
            }
        case .keyPress:
            Section("Args") { TextField("keys (e.g. cmd+s)", text: strArg(\.keys)) }
        case .scroll:
            Section("Args") {
                TextField("deltaX", text: intArg(\.deltaX))
                TextField("deltaY", text: intArg(\.deltaY))
            }
        case .wait:
            Section("Args") { TextField("seconds", text: doubleArg(\.seconds)) }
        case .menu:
            Section("Args") { TextField("menuPath (comma-separated)", text: listArg(\.menuPath)) }
        case .caption:
            Section("Args") {
                TextField("text", text: strArg(\.text))
                Picker("position", selection: positionArg) {
                    Text("bottom").tag("bottom"); Text("top").tag("top"); Text("center").tag("center")
                }
                TextField("holdMs", text: intArg(\.holdMs))
            }
        case .highlight:
            Section("Args") { TextField("holdMs", text: intArg(\.holdMs)) }
        case .pace:
            Section("Args") {
                TextField("typeMsPerChar", text: intArg(\.typeMsPerChar))
                TextField("stepDelayMs", text: intArg(\.stepDelayMs))
            }
        case .assertPixel, .assertRegion:
            Section("Args") { TextField("color (#RRGGBB)", text: strArg(\.color)) }
        case .screenshot:
            Section("Args") { TextField("path (optional)", text: strArg(\.path)) }
        default:
            EmptyView()
        }
    }

    // MARK: - Assert sub-form

    @ViewBuilder
    private func assertSection(_ step: Step) -> some View {
        Section("Assert") {
            Picker("property", selection: assertProperty) {
                ForEach(AssertProperty.allCasesForAuthoring, id: \.self) { Text($0.rawValue).tag($0) }
            }
            Picker("op", selection: assertOp) {
                ForEach(AssertOp.allCasesForAuthoring, id: \.self) { Text($0.rawValue).tag($0) }
            }
            TextField("expected", text: assertExpected)
        }
    }

    // MARK: - Bindings that route through PlanEditor mutators

    private var bindId: Binding<String> {
        Binding(get: { step?.id ?? "" }, set: { editor.setId($0, forStepAt: index) })
    }
    private var bindAction: Binding<Action> {
        Binding(get: { step?.action ?? .click }, set: { editor.setAction($0, forStepAt: index) })
    }
    private var bindLevel: Binding<StepLevel> {
        Binding(get: { step?.level ?? .happyPath }, set: { editor.setLevel($0, forStepAt: index) })
    }

    /// Mutate one field of the step's args via a keypath, going through setArgs so an
    /// emptied args block is dropped.
    private func mutateArgs(_ change: (inout ActionArgs) -> Void) {
        var a = step?.args ?? ActionArgs()
        change(&a)
        editor.setArgs(a, forStepAt: index)
    }

    private func strArg(_ kp: WritableKeyPath<ActionArgs, String?>) -> Binding<String> {
        Binding(get: { step?.args?[keyPath: kp] ?? "" },
                set: { v in mutateArgs { $0[keyPath: kp] = v.isEmpty ? nil : v } })
    }
    private func intArg(_ kp: WritableKeyPath<ActionArgs, Int?>) -> Binding<String> {
        Binding(get: { step?.args?[keyPath: kp].map(String.init) ?? "" },
                set: { v in mutateArgs { $0[keyPath: kp] = Int(v) } })
    }
    private func doubleArg(_ kp: WritableKeyPath<ActionArgs, Double?>) -> Binding<String> {
        Binding(get: { step?.args?[keyPath: kp].map { String($0) } ?? "" },
                set: { v in mutateArgs { $0[keyPath: kp] = Double(v) } })
    }
    private func boolArg(_ kp: WritableKeyPath<ActionArgs, Bool?>) -> Binding<Bool> {
        Binding(get: { step?.args?[keyPath: kp] ?? false },
                set: { v in mutateArgs { $0[keyPath: kp] = v ? true : nil } })
    }
    private func listArg(_ kp: WritableKeyPath<ActionArgs, [String]?>) -> Binding<String> {
        Binding(get: { step?.args?[keyPath: kp]?.joined(separator: ", ") ?? "" },
                set: { v in
                    let parts = v.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                    mutateArgs { $0[keyPath: kp] = parts.isEmpty ? nil : parts }
                })
    }
    private var positionArg: Binding<String> {
        Binding(get: { step?.args?.position ?? "bottom" },
                set: { v in mutateArgs { $0.position = v } })
    }

    // Assert field bindings — each reads the current Assertion (or a default) and
    // writes the whole thing back through setAssert.
    private func currentAssert() -> Assertion { step?.assert ?? Assertion(property: .value, op: .equals) }
    private var assertProperty: Binding<AssertProperty> {
        Binding(get: { step?.assert?.property ?? .value },
                set: { var a = currentAssert(); a.property = $0; editor.setAssert(a, forStepAt: index) })
    }
    private var assertOp: Binding<AssertOp> {
        Binding(get: { step?.assert?.op ?? .equals },
                set: { var a = currentAssert(); a.op = $0; editor.setAssert(a, forStepAt: index) })
    }
    private var assertExpected: Binding<String> {
        Binding(get: { step?.assert?.expected ?? "" },
                set: { var a = currentAssert(); a.expected = $0.isEmpty ? nil : $0; editor.setAssert(a, forStepAt: index) })
    }

    private func selectorLabel(_ s: AutopilotCore.Selector) -> String {
        if let id = s.identifier { return "#\(id)" }
        if let t = s.title { return "\(s.role ?? "?") “\(t)”" }
        return s.role ?? "—"
    }
}

// UI-facing enumerations of the assert property/op vocabulary. Kept here (not on the
// core enums, which are deliberately not CaseIterable) since they're a presentation
// concern. Element-targeted properties first; the target-less ones are usable too.
private extension AssertProperty {
    static var allCasesForAuthoring: [AssertProperty] {
        [.value, .title, .enabled, .focused, .position, .size, .marked, .count,
         .clipboard, .stdout, .stderr, .exitCode]
    }
}
private extension AssertOp {
    static var allCasesForAuthoring: [AssertOp] {
        [.equals, .notEquals, .contains, .matches, .exists, .notExists, .greaterThan, .lessThan]
    }
}
