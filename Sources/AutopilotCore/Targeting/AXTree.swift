import Foundation
import ApplicationServices

/// Attribute reads + tree traversal over the Accessibility API.
public enum AXTree {
    /// Read a string attribute (e.g. kAXRoleAttribute) or nil.
    public static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard err == .success else { return nil }
        return value as? String
    }

    /// Read a bool attribute, or nil.
    public static func bool(_ element: AXUIElement, _ attribute: String) -> Bool? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard err == .success else { return nil }
        return (value as? NSNumber)?.boolValue
    }

    /// Read frame (position + size) in screen coordinates, or nil.
    public static func frame(_ element: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success
        else { return nil }
        var point = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posRef as! AXValue, .cgPoint, &point)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        return CGRect(origin: point, size: size)
    }

    /// Immediate children of an element.
    public static func children(_ element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)
        guard err == .success, let arr = value as? [AXUIElement] else { return [] }
        return arr
    }

    /// The application-level AX element for a running process.
    public static func application(pid: pid_t) -> AXUIElement {
        AXUIElementCreateApplication(pid)
    }

    /// Perform the AX press action on an element (buttons, menu items, etc.).
    /// More robust than a coordinate click and works for elements that have no
    /// stable on-screen frame (e.g. items in a closed menu). Returns success.
    @discardableResult
    public static func press(_ element: AXUIElement) -> Bool {
        AXUIElementPerformAction(element, kAXPressAction as CFString) == .success
    }

    /// Read the menu-item mark character (e.g. a checkmark) if present.
    /// Menu state is otherwise not observable; this is the one readable signal.
    public static func menuMarkChar(_ element: AXUIElement) -> String? {
        string(element, kAXMenuItemMarkCharAttribute as String)
    }

    /// Depth-first pre-order walk, invoking `visit` on every descendant
    /// (including `root`). Bounded by `maxNodes` as a runaway guard.
    public static func walk(_ root: AXUIElement, maxNodes: Int = 5000,
                            visit: (AXUIElement) -> Void) {
        var stack = [root]
        var count = 0
        while let el = stack.popLast() {
            visit(el)
            count += 1
            if count >= maxNodes { return }
            stack.append(contentsOf: children(el).reversed())
        }
    }

    /// A JSON-serializable snapshot of the subtree (role/identifier/title/value/frame),
    /// used for failure diagnostics.
    public static func snapshot(_ root: AXUIElement, maxNodes: Int = 2000) -> [[String: String]] {
        var out: [[String: String]] = []
        walk(root, maxNodes: maxNodes) { el in
            var node: [String: String] = [:]
            if let r = string(el, kAXRoleAttribute as String) { node["role"] = r }
            if let id = string(el, kAXIdentifierAttribute as String) { node["identifier"] = id }
            if let t = string(el, kAXTitleAttribute as String) { node["title"] = t }
            if let v = string(el, kAXValueAttribute as String) { node["value"] = v }
            if let f = frame(el) {
                node["frame"] = "\(Int(f.minX)),\(Int(f.minY)),\(Int(f.width)),\(Int(f.height))"
            }
            out.append(node)
        }
        return out
    }
}
