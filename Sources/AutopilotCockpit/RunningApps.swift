import AppKit

/// A user-facing running application the cockpit can attach to.
struct RunningApp: Identifiable, Equatable {
    let pid: Int32
    let name: String
    let bundleId: String?
    var id: Int32 { pid }
}

/// Pure list-builder over NSRunningApplication so it can be unit-tested and the
/// UI stays a thin caller.
enum RunningApps {
    static func list(_ apps: [NSRunningApplication]) -> [RunningApp] {
        apps.filter { $0.activationPolicy == .regular && $0.processIdentifier > 0 }
            .map { RunningApp(pid: $0.processIdentifier,
                              name: $0.localizedName ?? "pid \($0.processIdentifier)",
                              bundleId: $0.bundleIdentifier) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Live snapshot for the UI.
    static func current() -> [RunningApp] { list(NSWorkspace.shared.runningApplications) }
}
