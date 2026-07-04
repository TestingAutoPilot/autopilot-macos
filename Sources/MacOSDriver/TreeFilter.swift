import Foundation

/// Pure filters over a flat AX-tree snapshot (`[[String:String]]` nodes with a
/// `role` and a `frame` = "minX,minY,w,h"). Used by `dump-axtree` to trim a large
/// tree — the report noted a real app's dump was ~270 nodes incl. the whole
/// system menu bar. Pure so it's unit-testable without a running app.
public enum TreeFilter {
    /// Menu-bar / menu roles that dominate a full dump but are rarely the target
    /// of authoring. `--omit-menubar` drops these.
    static let menuRoles: Set<String> = [
        "AXMenuBar", "AXMenuBarItem", "AXMenu", "AXMenuItem",
    ]

    /// Drop menu-bar and menu nodes.
    public static func omitMenuBar(_ nodes: [[String: String]]) -> [[String: String]] {
        nodes.filter { !menuRoles.contains($0["role"] ?? "") }
    }

    /// Keep only nodes inside the subtree of the FIRST node whose role == `role`
    /// (that node included). "Inside" = the node's frame is contained by the
    /// anchor's frame. Frameless nodes are dropped (can't be placed). If no node
    /// has that role, returns an empty array.
    public static func underRole(_ role: String, _ nodes: [[String: String]]) -> [[String: String]] {
        guard let anchor = nodes.first(where: { $0["role"] == role }),
              let anchorRect = rect(anchor) else { return [] }
        return nodes.filter { node in
            guard let r = rect(node) else { return false }
            return anchorRect.contains(r) || r == anchorRect
        }
    }

    /// Parse a "minX,minY,w,h" frame string into a CGRect; nil if absent/malformed.
    static func rect(_ node: [String: String]) -> CGRect? {
        guard let s = node["frame"] else { return nil }
        let p = s.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard p.count == 4 else { return nil }
        return CGRect(x: p[0], y: p[1], width: p[2], height: p[3])
    }
}
