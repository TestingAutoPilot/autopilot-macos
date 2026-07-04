import Foundation
import ApplicationServices
import AutopilotCore

/// Drives the menu bar by title path, e.g. ["View", "Rainbow Brackets"].
/// This is how menu commands without a key equivalent are invoked — a plain
/// coordinate click cannot open a closed menu.
public struct MenuNavigator {
    public init() {}

    public enum MenuError: Error, CustomStringConvertible {
        case noMenuBar
        case itemNotFound(title: String, available: [String])
        public var description: String {
            switch self {
            case .noMenuBar: return "Application has no menu bar"
            case .itemNotFound(let t, let avail):
                return "Menu item '\(t)' not found. Available: \(avail.joined(separator: ", "))"
            }
        }
    }

    /// Pure helper: among `children`, return the index of the first whose title
    /// equals `title`. Titles are read by the caller; this keeps matching testable.
    public static func indexOfTitle(_ title: String, in titles: [String?]) -> Int? {
        titles.firstIndex { $0 == title }
    }

    /// Walk the menu bar along `path` and press the final item.
    /// `app` is the application AX element.
    public func selectPath(_ path: [String], app: AXUIElement) throws {
        guard !path.isEmpty else { return }
        var menuBarRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXMenuBarAttribute as CFString, &menuBarRef) == .success,
              let menuBar = menuBarRef else { throw MenuError.noMenuBar }
        // swiftlint:disable:next force_cast
        var current = menuBar as! AXUIElement

        for (depth, title) in path.enumerated() {
            // Children of a menu-bar item are wrapped in an AXMenu; descend through it.
            let candidates = childMenuItems(of: current)
            let titles = candidates.map { AXTree.string($0, kAXTitleAttribute as String) }
            guard let idx = Self.indexOfTitle(title, in: titles) else {
                throw MenuError.itemNotFound(title: title,
                                             available: titles.compactMap { $0 })
            }
            let item = candidates[idx]
            if depth == path.count - 1 {
                AXTree.press(item)            // leaf: invoke it
            } else {
                AXTree.press(item)            // open the submenu
                current = item
            }
        }
    }

    /// List every item of the menu reached by `path` — INCLUDING disabled items —
    /// as neutral `MenuItemInfo`. `path` names the containing menu (e.g. ["View"]
    /// lists the View menu's items; ["Edit","Text"] lists the Text submenu's).
    /// An empty `path` lists the top-level menu-bar titles.
    ///
    /// Why: `selectPath` can only invoke an ENABLED item, and disabled items (a
    /// command needing a specific first-responder) don't appear in any discovery
    /// output. This lets an author see the whole menu and each item's enabled/mark
    /// state without invoking anything.
    public func listItems(path: [String], app: AXUIElement) throws -> [MenuItemInfo] {
        var menuBarRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXMenuBarAttribute as CFString, &menuBarRef) == .success,
              let menuBar = menuBarRef else { throw MenuError.noMenuBar }
        // swiftlint:disable:next force_cast
        var current = menuBar as! AXUIElement

        // Descend to the menu named by `path`; the items we list are that menu's
        // children. For an empty path, the menu bar's own items are the top titles.
        for title in path {
            let candidates = childMenuItems(of: current)
            let titles = candidates.map { AXTree.string($0, kAXTitleAttribute as String) }
            guard let idx = Self.indexOfTitle(title, in: titles) else {
                throw MenuError.itemNotFound(title: title, available: titles.compactMap { $0 })
            }
            current = candidates[idx]
        }

        return childMenuItems(of: current).map { item in
            let title = AXTree.string(item, kAXTitleAttribute as String) ?? ""
            let enabled = AXTree.bool(item, kAXEnabledAttribute as String) ?? true
            // An item with a non-empty AXMenu child opens a submenu.
            let hasSubmenu = AXTree.children(item).contains {
                AXTree.string($0, kAXRoleAttribute as String) == (kAXMenuRole as String)
            }
            // AXMenuItemMarkChar is the checkmark glyph when marked; empty/absent otherwise.
            let mark = AXTree.string(item, kAXMenuItemMarkCharAttribute as String)
            let markChar = (mark?.isEmpty == false) ? mark : nil
            return MenuItemInfo(title: title, enabled: enabled, hasSubmenu: hasSubmenu, markChar: markChar)
        }
    }

    /// Return the selectable items under a menu-bar item or menu element,
    /// transparently descending through an intervening AXMenu container.
    private func childMenuItems(of element: AXUIElement) -> [AXUIElement] {
        let children = AXTree.children(element)
        // A menu-bar item contains one AXMenu whose children are the items.
        if children.count == 1,
           AXTree.string(children[0], kAXRoleAttribute as String) == (kAXMenuRole as String) {
            return AXTree.children(children[0])
        }
        return children
    }
}
