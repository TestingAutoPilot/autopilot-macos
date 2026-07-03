import SwiftUI
import AppKit
import AutopilotCore
import MacOSDriver

/// Run mode: pick a plan, pick a level tier, run, watch live pass/fail.
struct RunView: View {
    @Bindable var engine: CockpitEngine
    @State private var controller = RunController()
    @State private var loaded: LoadedPlan?
    @State private var loadError: String?
    @State private var maxLevel: StepLevel = .tryToBreakIt
    @State private var keepGoing = true
    @State private var selectedRow: String?

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            Divider()
            if let loaded {
                if !loaded.findings.isEmpty {
                    DisclosureGroup("Lint findings (\(loaded.findings.count))") {
                        ForEach(loaded.findings, id: \.self) { Text($0).font(.callout) }
                    }.padding(8)
                }
                HSplitView {
                    List(controller.rows, selection: $selectedRow) { row in
                        HStack {
                            Image(systemName: row.state.symbol)
                            Text(row.id)
                            Spacer()
                            if let d = row.durationMs { Text("\(d) ms").foregroundStyle(.secondary) }
                        }.tag(row.id)
                    }.frame(minWidth: 280)
                    ArtifactPane(screenshot: selectedStepRow?.screenshot,
                                 axDump: selectedStepRow?.axDump)
                        .frame(minWidth: 280)
                }
                if let report = controller.report {
                    Text(reportSummary(report)).font(.callout).padding(8)
                }
            } else {
                ContentUnavailableView("No plan loaded", systemImage: "doc.badge.plus",
                    description: Text(loadError ?? "Open a .json plan to run."))
            }
        }
    }

    private var controlBar: some View {
        HStack(spacing: 10) {
            Button("Open Plan…") { openPlan() }
            Picker("Level", selection: $maxLevel) {
                Text("happyPath").tag(StepLevel.happyPath)
                Text("integrationSuite").tag(StepLevel.integrationSuite)
                Text("tryToBreakIt").tag(StepLevel.tryToBreakIt)
            }.frame(width: 220)
            Toggle("Keep going", isOn: $keepGoing)
            Spacer()
            Button {
                guard let loaded else { return }
                controller.run(loaded, driver: MacOSDriver(), maxLevel: maxLevel, keepGoing: keepGoing)
            } label: { Label("Run", systemImage: "play.fill") }
            .disabled(loaded == nil || controller.isRunning)
        }.padding(8)
    }

    private var selectedStepRow: StepRow? {
        controller.rows.first { $0.id == selectedRow }
    }

    private func openPlan() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        switch PlanDocument.load(url: url) {
        case .success(let l): loaded = l; loadError = nil
        case .failure(let err): loaded = nil; loadError = "\(err)"
        }
    }

    private func reportSummary(_ r: Report) -> String {
        let b = r.steps.reduce(into: (p: 0, f: 0, e: 0, s: 0)) { acc, s in
            switch s.result {
            case .pass: acc.p += 1
            case .fail: acc.f += 1
            case .error: acc.e += 1
            case .skipped: acc.s += 1
            }
        }
        return "\(r.result.rawValue.uppercased()) — \(b.p) pass, \(b.f) fail, \(b.e) error, \(b.s) skipped, \(r.durationMs) ms"
    }
}
