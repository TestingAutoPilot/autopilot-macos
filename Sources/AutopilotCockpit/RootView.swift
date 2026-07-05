import SwiftUI

struct RootView: View {
    @State private var mode: CockpitMode = .inspect
    @State private var engine = CockpitEngine()

    var body: some View {
        VStack(spacing: 0) {
            if !engine.hasAccessibility {
                PermissionBanner(instructions: engine.accessibilityInstructions()) {
                    engine.checkAccessibility()
                }
            }
            TargetBar(engine: engine)
            Divider()
            Picker("Mode", selection: $mode) {
                ForEach(CockpitMode.allCases) { m in Text(m.title).tag(m) }
            }
            .pickerStyle(.segmented).labelsHidden().padding(8)
            Divider()

            switch mode {
            case .inspect: InspectView(engine: engine)
            case .author:  AuthorView(engine: engine)
            case .run:     RunView(engine: engine)
            }
        }
        .onAppear {
            engine.checkAccessibility()
            applyLaunchArguments()
        }
    }

    /// Optional launch arguments so the Cockpit can start in a known state
    /// (attached to a process, on a given mode) — useful for scripting, demos,
    /// and documentation capture. Both are optional and ignored if absent.
    ///   --attach-pid <pid>          pre-attach to that process on startup
    ///   --mode <inspect|author|run> start on that mode
    private func applyLaunchArguments() {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--attach-pid"), i + 1 < args.count,
           let pid = Int32(args[i + 1]) {
            engine.attach(pid: pid)
            engine.refreshTree()
        }
        if let i = args.firstIndex(of: "--mode"), i + 1 < args.count,
           let m = CockpitMode(rawValue: args[i + 1].lowercased()) {
            mode = m
        }
    }
}
