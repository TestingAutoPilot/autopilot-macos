import SwiftUI

struct RootView: View {
    @State private var mode: CockpitMode = .inspect

    var body: some View {
        VStack(spacing: 0) {
            Picker("Mode", selection: $mode) {
                ForEach(CockpitMode.allCases) { m in
                    Text(m.title).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(8)

            Divider()

            switch mode {
            case .inspect: Text("Inspect").frame(maxWidth: .infinity, maxHeight: .infinity)
            case .author:  Text("Author").frame(maxWidth: .infinity, maxHeight: .infinity)
            case .run:     Text("Run").frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
