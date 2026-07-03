import SwiftUI

/// Top bar: pick a running app to attach to, show connection status, refresh.
struct TargetBar: View {
    @Bindable var engine: CockpitEngine
    @State private var apps: [RunningApp] = []
    @State private var selectedPid: Int32?

    var body: some View {
        HStack(spacing: 10) {
            Text("Target:")
            Picker("Target", selection: $selectedPid) {
                Text("— choose an app —").tag(Int32?.none)
                ForEach(apps) { app in
                    Text(app.name).tag(Int32?.some(app.pid))
                }
            }
            .labelsHidden()
            .frame(minWidth: 220)
            .onChange(of: selectedPid) { _, pid in
                if let pid { engine.attach(pid: pid); engine.refreshTree() }
            }

            Button {
                apps = RunningApps.current()
            } label: { Image(systemName: "arrow.clockwise") }
            .help("Reload the list of running apps")

            statusLabel
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .onAppear { apps = RunningApps.current() }
    }

    @ViewBuilder private var statusLabel: some View {
        if let h = engine.attached {
            Label(h.appName, systemImage: "circle.fill")
                .foregroundStyle(.green).labelStyle(.titleAndIcon)
        } else {
            Label("Not attached", systemImage: "circle")
                .foregroundStyle(.secondary)
        }
    }
}
