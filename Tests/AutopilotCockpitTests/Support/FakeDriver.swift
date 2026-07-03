import Foundation
import AutopilotCore

/// Local test double mirroring autopilot-core's FakeDriver (which is internal to
/// core's own test target). Only the members the cockpit exercises need real
/// behavior; the rest are inert.
final class FakeElement: ElementHandle { let tag: String; init(_ t: String) { tag = t } }

struct FakeDriver: AppDriver {
    var nodes: [[String: String]] = []
    var accessibility = true
    func launch(_ target: TargetApp) throws -> LaunchedHandle { LaunchedHandle(pid: 1, appName: "Fake") }
    func attach(_ target: TargetApp) throws -> LaunchedHandle { LaunchedHandle(pid: 1, appName: "Fake") }
    func attach(pid: Int32) throws -> LaunchedHandle { LaunchedHandle(pid: pid, appName: "Fake\(pid)") }
    func terminate(_ app: LaunchedHandle) {}
    func activate(_ app: LaunchedHandle, timeoutMs: Int, intervalMs: Int) -> Bool { true }
    func hasAccessibility() -> Bool { accessibility }
    func hasScreenRecording() -> Bool { true }
    func accessibilityInstructions() -> String { "grant ax in System Settings" }
    func screenRecordingInstructions() -> String { "grant sr" }
    func resolve(_ selector: AutopilotCore.Selector, app: LaunchedHandle, timeoutMs: Int, intervalMs: Int, baseDir: URL?) throws -> ResolvedElement { .element(FakeElement("x")) }
    func waitForPresence(_ selector: AutopilotCore.Selector, present: Bool, app: LaunchedHandle, timeoutMs: Int, intervalMs: Int) -> Bool { present }
    func matchCount(_ selector: AutopilotCore.Selector, app: LaunchedHandle) -> Int { nodes.count }
    func findAll(_ selector: AutopilotCore.Selector, app: LaunchedHandle) -> [String] { [] }
    func perform(action: Action, args: ActionArgs?, on element: ResolvedElement?) throws {}
    func point(for element: ResolvedElement) -> Point? { Point(x: 0, y: 0) }
    func performDrag(from: Point, to: Point) throws {}
    func performFileDrag(files: [String], to: Point) throws {}
    func selectMenuPath(_ path: [String], app: LaunchedHandle) throws {}
    func readProperty(_ property: AssertProperty, of element: any ElementHandle) -> String? { "fake" }
    func captureElementScreenshot(_ element: any ElementHandle, to path: String, padding: Int, metadata: [String: String]) -> String? { nil }
    func captureMainDisplay(to path: String, metadata: [String: String]) -> Bool { true }
    func captureRegion(_ rect: Rect, to path: String, metadata: [String: String]) -> Bool { true }
    func samplePixel(at point: Point) -> RGBColor? { RGBColor(r: 0, g: 0, b: 0) }
    func sampleRegion(_ rect: Rect) -> [RGBColor] { [] }
    func loadPNG(_ path: String) -> [RGBColor]? { nil }
    func dumpTree(app: LaunchedHandle) -> TreeSnapshot { TreeSnapshot(nodes: nodes, truncated: false) }
    func suggestSelectors(app: LaunchedHandle) -> [SelectorSuggester.Suggestion] {
        SelectorSuggester.suggest(from: nodes)
    }
}
