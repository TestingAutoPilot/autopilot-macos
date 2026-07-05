import Testing
import CoreGraphics
@testable import AutopilotCockpit

@Suite struct TreeBuilderTests {
    @Test func parsesFrameString() {
        let n = AXNode(index: 0, attrs: ["role": "AXButton", "frame": "10,20,30,40"])
        #expect(n.frame == CGRect(x: 10, y: 20, width: 30, height: 40))
    }

    @Test func nestsByContainment() {
        // window contains a group; group contains a button.
        let nodes: [[String: String]] = [
            ["role": "AXWindow", "frame": "0,0,100,100"],
            ["role": "AXGroup",  "frame": "10,10,80,80"],
            ["role": "AXButton", "identifier": "ok", "frame": "20,20,20,20"],
        ]
        let roots = TreeBuilder.build(from: nodes)
        #expect(roots.count == 1)
        #expect(roots[0].role == "AXWindow")
        #expect(roots[0].children.count == 1)
        #expect(roots[0].children[0].role == "AXGroup")
        #expect(roots[0].children[0].children.count == 1)
        #expect(roots[0].children[0].children[0].identifier == "ok")
    }

    @Test func siblingsUnderSameParent() {
        let nodes: [[String: String]] = [
            ["role": "AXWindow", "frame": "0,0,100,100"],
            ["role": "AXButton", "frame": "10,10,10,10"],
            ["role": "AXButton", "frame": "50,50,10,10"],
        ]
        let roots = TreeBuilder.build(from: nodes)
        #expect(roots.count == 1)
        #expect(roots[0].children.count == 2)
    }

    @Test func nodesWithoutFramesBecomeRoots() {
        let nodes: [[String: String]] = [
            ["role": "AXMenuBar"],                      // no frame
            ["role": "AXWindow", "frame": "0,0,50,50"], // has frame
        ]
        let roots = TreeBuilder.build(from: nodes)
        #expect(roots.count == 2)
    }
}
