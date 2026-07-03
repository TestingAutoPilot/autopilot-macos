import Testing
@testable import AutopilotCockpit
import AutopilotCore

@MainActor
@Suite struct SelectorHandoffTests {
    @Test func selectorForNodePrefersIdentifier() {
        let engine = CockpitEngine(driver: FakeDriver())
        let node = AXNode(index: 0, attrs: ["role": "AXButton", "identifier": "ok"])
        #expect(engine.selector(for: node).identifier == "ok")
    }

    @Test func selectorForNodeFallsBackToTitle() {
        let engine = CockpitEngine(driver: FakeDriver())
        let node = AXNode(index: 0, attrs: ["role": "AXButton", "title": "Log In"])
        let s = engine.selector(for: node)
        #expect(s.identifier == nil)
        #expect(s.title == "Log In")
        #expect(s.role == "AXButton")
    }

    @Test func pendingSelectorRoundTrips() {
        let engine = CockpitEngine(driver: FakeDriver())
        engine.pendingSelector = AutopilotCore.Selector(identifier: "go")
        #expect(engine.pendingSelector?.identifier == "go")
    }
}
