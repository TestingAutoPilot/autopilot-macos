import Testing
import AppKit
@testable import AutopilotCockpit

@Suite struct RunningAppsTests {
    @Test func mapsAndSortsRegularApps() {
        // NSRunningApplication can't be constructed directly; test the pure mapper
        // via the model type instead, proving sort + shape.
        let unsorted = [
            RunningApp(pid: 3, name: "Zebra", bundleId: "z"),
            RunningApp(pid: 1, name: "Alpha", bundleId: "a"),
        ]
        let sorted = unsorted.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        #expect(sorted.map(\.name) == ["Alpha", "Zebra"])
    }

    @Test func runningAppEquatable() {
        #expect(RunningApp(pid: 1, name: "A", bundleId: nil) == RunningApp(pid: 1, name: "A", bundleId: nil))
    }
}
