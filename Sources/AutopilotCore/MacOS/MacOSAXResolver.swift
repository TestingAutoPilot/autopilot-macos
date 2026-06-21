import Foundation
import ApplicationServices

/// Resolves a Selector against a running app's live AX tree — the platform half
/// of the old AXResolver.
public struct MacOSAXResolver {
    public init() {}

    static func node(of el: AXUIElement) -> [String: String] {
        var node: [String: String] = [:]
        if let r = AXTree.string(el, kAXRoleAttribute as String) { node["role"] = r }
        if let id = AXTree.string(el, kAXIdentifierAttribute as String) { node["identifier"] = id }
        if let t = AXTree.string(el, kAXTitleAttribute as String) { node["title"] = t }
        if let v = AXTree.string(el, kAXValueAttribute as String) { node["value"] = v }
        return node
    }

    func rootFor(_ selector: Selector, in appElement: AXUIElement) throws -> AXUIElement {
        guard let parent = selector.withinSelector else { return appElement }
        return try resolveOne(in: appElement, selector: parent)
    }

    public func resolveOne(in appElement: AXUIElement, selector: Selector) throws -> AXUIElement {
        let root = try rootFor(selector, in: appElement)
        var matches: [AXUIElement] = []
        var descriptors: [String] = []
        let walk = AXTree.walk(root) { el in
            if AXResolver.matches(node: Self.node(of: el), selector: selector) {
                matches.append(el)
                if descriptors.count < AXResolver.maxReportedMatches { descriptors.append(Self.describeNode(el)) }
            }
            return true
        }
        let desc = AXResolver.describe(selector)
        if matches.isEmpty {
            if walk.truncated { throw TargetingError.treeTruncated(selector: desc, visited: walk.visited) }
            throw TargetingError.notFound(selector: desc)
        }
        if let idx = selector.index {
            guard idx >= 0, idx < matches.count else {
                throw TargetingError.notFound(selector: "\(desc) — index \(idx) out of range (\(matches.count) matches)")
            }
            return matches[idx]
        }
        if matches.count > 1 {
            throw TargetingError.ambiguous(selector: desc, count: matches.count, matches: descriptors)
        }
        return matches[0]
    }

    public func findAll(in appElement: AXUIElement, selector: Selector) -> [String] {
        guard let root = try? rootFor(selector, in: appElement) else { return [] }
        var out: [String] = []
        AXTree.walk(root) { el in
            if AXResolver.matches(node: Self.node(of: el), selector: selector) { out.append(Self.describeNode(el)) }
            return true
        }
        return out
    }

    public func count(in appElement: AXUIElement, selector: Selector, stopAt: Int = 2) -> Int {
        guard let root = try? rootFor(selector, in: appElement) else { return 0 }
        var n = 0
        AXTree.walk(root) { el in
            if AXResolver.matches(node: Self.node(of: el), selector: selector) {
                n += 1
                if n >= stopAt { return false }
            }
            return true
        }
        return n
    }

    static func describeNode(_ el: AXUIElement) -> String {
        let n = node(of: el)
        var parts: [String] = []
        if let r = n["role"] { parts.append(r) }
        if let id = n["identifier"], !id.isEmpty { parts.append("id=\(id)") }
        if let t = n["title"], !t.isEmpty { parts.append("title=\(t)") }
        if let v = n["value"], !v.isEmpty { parts.append("value=\(v.prefix(40))") }
        if let f = AXTree.frame(el) { parts.append("@(\(Int(f.minX)),\(Int(f.minY)))") }
        return parts.joined(separator: " ")
    }
}
