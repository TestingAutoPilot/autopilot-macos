import SwiftUI
import AppKit
import AutopilotCore

/// Author mode (basic): load a plan, edit its step list, apply a selector picked
/// in Inspect, save valid JSON. Full per-action visual editing is a later phase.
struct AuthorView: View {
    @Bindable var engine: CockpitEngine
    @State private var editor: PlanEditor?
    @State private var selection: Int?
    @State private var status: String?

    /// Actions offered in the "Add Step" menu. `Action` is not CaseIterable, and
    /// a short, practical list is better UX than every raw case anyway.
    private let authorableActions: [Action] = [
        .click, .doubleClick, .rightClick, .press, .type, .keyPress, .setValue,
        .menu, .assert, .waitFor, .screenshot, .launch, .terminate, .wait,
    ]

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            Divider()
            if let editor {
                List(selection: $selection) {
                    ForEach(Array(editor.plan.steps.enumerated()), id: \.offset) { idx, step in
                        HStack {
                            Text(step.action.rawValue).bold()
                            if let t = step.target { Text(selectorLabel(t)).foregroundStyle(.secondary) }
                            Spacer()
                            Text(step.level.rawValue).font(.caption).foregroundStyle(.secondary)
                        }.tag(idx)
                    }
                    .onDelete { editor.deleteStep(at: $0) }
                    .onMove { editor.moveStep(from: $0, to: $1) }
                }
                if let status { Text(status).font(.callout).padding(6) }
            } else {
                ContentUnavailableView("No plan open", systemImage: "square.and.pencil",
                    description: Text("Open a plan or start a new one."))
            }
        }
    }

    private var controlBar: some View {
        HStack(spacing: 10) {
            Button("Open…") { openPlan() }
            Button("New") { editor = PlanEditor(plan: emptyPlan()); status = "new plan" }
            Menu("Add Step") {
                ForEach(authorableActions, id: \.self) { a in
                    Button(a.rawValue) { editor?.addStep(action: a, level: .happyPath) }
                }
            }.disabled(editor == nil)
            Button("Apply Selector from Inspect") {
                if let editor, let sel = engine.pendingSelector, let idx = selection {
                    editor.setSelector(sel, forStepAt: idx)
                    status = "applied selector to step \(idx + 1)"
                }
            }.disabled(editor == nil || selection == nil || engine.pendingSelector == nil)
            Spacer()
            Button("Save…") { savePlan() }.disabled(editor == nil)
        }.padding(8)
    }

    private func selectorLabel(_ s: AutopilotCore.Selector) -> String {
        if let id = s.identifier { return "#\(id)" }
        if let t = s.title { return "\(s.role ?? "?") “\(t)”" }
        return s.role ?? "—"
    }

    private func emptyPlan() -> Plan {
        Plan(schemaVersion: "1.1", name: "new-plan",
             target: TargetApp(bundleId: "com.example"),
             steps: [])
    }

    private func openPlan() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        switch PlanDocument.load(url: url) {
        case .success(let l):
            editor = PlanEditor(plan: l.plan)
            status = l.findings.isEmpty ? "loaded" : "loaded with \(l.findings.count) lint finding(s)"
        case .failure(let err):
            status = "load failed: \(err)"
        }
    }

    private func savePlan() {
        guard let editor else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(editor.plan.name).json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try editor.encoded().write(to: url)
            // Re-lint what we just wrote so the author sees issues immediately.
            if case .success(let l) = PlanDocument.load(url: url) {
                status = l.findings.isEmpty ? "saved ✓ (lint clean)" : "saved — \(l.findings.count) lint finding(s)"
            } else { status = "saved" }
        } catch { status = "save failed: \(error)" }
    }
}
