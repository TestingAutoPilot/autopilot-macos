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
            case .author:  Text("Author — coming in Task 9").frame(maxWidth: .infinity, maxHeight: .infinity)
            case .run:     RunView(engine: engine)
            }
        }
        .onAppear { engine.checkAccessibility() }
    }
}
