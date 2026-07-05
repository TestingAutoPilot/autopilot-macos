import Testing
import Foundation
@testable import AutopilotCockpit
import AutopilotCore

@MainActor
@Suite struct CockpitEngineTests {
    @Test func attachThenRefreshBuildsTreeAndSuggestions() {
        let driver = FakeDriver(nodes: [
            ["role": "AXWindow", "frame": "0,0,100,100"],
            ["role": "AXButton", "identifier": "ok", "frame": "10,10,20,20"],
        ])
        let engine = CockpitEngine(driver: driver)
        engine.attach(pid: 42)
        #expect(engine.attached?.pid == 42)
        engine.refreshTree()
        #expect(engine.roots.count == 1)
        #expect(engine.roots[0].children.count == 1)
        // AXButton with an identifier yields a stable-identifier suggestion.
        #expect(engine.suggestions.contains { $0.selector.identifier == "ok" })
        #expect(engine.lastError == nil)
    }

    @Test func refreshWithoutAttachSetsError() {
        let engine = CockpitEngine(driver: FakeDriver())
        engine.refreshTree()
        #expect(engine.lastError != nil)
        #expect(engine.roots.isEmpty)
    }

    @Test func accessibilityReflectsDriver() {
        let engine = CockpitEngine(driver: FakeDriver(nodes: [], accessibility: false))
        engine.checkAccessibility()
        #expect(engine.hasAccessibility == false)
    }
}
