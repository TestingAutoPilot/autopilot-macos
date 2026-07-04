import Testing
@testable import MacOSDriver

@Suite struct TreeFilterTests {
    private let tree: [[String: String]] = [
        ["role": "AXMenuBar", "frame": "0,0,1440,24"],
        ["role": "AXMenuBarItem", "title": "File", "frame": "10,0,40,24"],
        ["role": "AXWindow", "frame": "100,100,800,600"],
        ["role": "AXButton", "identifier": "ok", "frame": "120,120,80,30"],
        ["role": "AXTextField", "identifier": "name", "frame": "120,160,200,24"],
        ["role": "AXStaticText", "frame": "5000,5000,10,10"],  // off in a different window
    ]

    @Test func omitMenuBarDropsMenuRoles() {
        let out = TreeFilter.omitMenuBar(tree)
        #expect(!out.contains { $0["role"] == "AXMenuBar" })
        #expect(!out.contains { $0["role"] == "AXMenuBarItem" })
        #expect(out.contains { $0["role"] == "AXWindow" })
    }

    @Test func underRoleKeepsOnlyContainedNodes() {
        let out = TreeFilter.underRole("AXWindow", tree)
        let roles = out.compactMap { $0["role"] }
        #expect(roles.contains("AXWindow"))
        #expect(roles.contains("AXButton"))
        #expect(roles.contains("AXTextField"))
        // The menu bar and the far-away node are outside the window frame.
        #expect(!roles.contains("AXMenuBar"))
        #expect(!roles.contains("AXStaticText"))
    }

    @Test func underRoleMissingRoleReturnsEmpty() {
        #expect(TreeFilter.underRole("AXSheet", tree).isEmpty)
    }
}
