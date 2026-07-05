import Foundation
import Observation
import AutopilotCore
import MacOSDriver

/// The single seam between SwiftUI and the AutoPilot framework. Owns the driver
/// and the currently-attached target; every view goes through this. Serializes
/// driver access implicitly by being @MainActor (one op at a time from the UI).
@MainActor
@Observable
final class CockpitEngine {
    private let driver: any AppDriver

    private(set) var attached: LaunchedHandle?
    private(set) var roots: [AXNode] = []
    private(set) var suggestions: [SelectorSuggester.Suggestion] = []
    private(set) var treeTruncated = false
    private(set) var lastError: String?
    var hasAccessibility: Bool = true

    /// A selector chosen in Inspect, waiting to be applied to a step in Author.
    var pendingSelector: AutopilotCore.Selector?

    init(driver: any AppDriver = MacOSDriver()) {
        self.driver = driver
    }

    /// The preferred selector for a node: stable identifier > role+title > role.
    /// Shared by Inspect's "Copy selector" and "Use as selector" so both agree.
    func selector(for node: AXNode) -> AutopilotCore.Selector {
        if let id = node.identifier,
           let s = suggestions.first(where: { $0.selector.identifier == id }) {
            return s.selector
        }
        if let id = node.identifier { return AutopilotCore.Selector(identifier: id) }
        if let t = node.title { return AutopilotCore.Selector(role: node.role, title: t) }
        return AutopilotCore.Selector(role: node.role)
    }

    func checkAccessibility() {
        hasAccessibility = driver.hasAccessibility()
    }

    /// The System Settings instructions to show when accessibility is missing.
    func accessibilityInstructions() -> String { driver.accessibilityInstructions() }

    func attach(pid: Int32) {
        do {
            attached = try driver.attach(pid: pid)
            lastError = nil
        } catch {
            attached = nil
            lastError = "attach failed: \(error)"
        }
    }

    func refreshTree() {
        guard let app = attached else {
            lastError = "not attached to any app"
            roots = []; suggestions = []
            return
        }
        let snap = driver.dumpTree(app: app)
        roots = TreeBuilder.build(from: snap.nodes)
        treeTruncated = snap.truncated
        suggestions = driver.suggestSelectors(app: app)
        lastError = nil
    }
}
