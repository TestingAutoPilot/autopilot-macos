import SwiftUI

/// The three modes of the cockpit. Ordered as displayed in the switcher.
public enum CockpitMode: String, CaseIterable, Identifiable {
    case inspect, author, run
    public var id: String { rawValue }
    var title: String {
        switch self {
        case .inspect: return "Inspect"
        case .author:  return "Author"
        case .run:     return "Run"
        }
    }
}

@main
struct AutopilotCockpitApp: App {
    var body: some Scene {
        WindowGroup("AutoPilot Cockpit") {
            RootView()
                .frame(minWidth: 900, minHeight: 600)
        }
    }
}
