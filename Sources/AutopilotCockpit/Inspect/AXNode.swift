import CoreGraphics
import Foundation

/// A display node in the inspector tree, built from one flat AX snapshot node.
struct AXNode: Identifiable, Equatable {
    let id: Int                 // index in the flat snapshot array
    let attrs: [String: String]
    var children: [AXNode]

    init(index: Int, attrs: [String: String], children: [AXNode] = []) {
        self.id = index; self.attrs = attrs; self.children = children
    }

    /// OutlineGroup's `children:` needs an OPTIONAL key path so leaves (nil) render
    /// without a disclosure triangle. `children` itself stays non-optional.
    var childrenOrNil: [AXNode]? { children.isEmpty ? nil : children }

    var role: String { attrs["role"] ?? "AXUnknown" }
    var identifier: String? { attrs["identifier"]?.nilIfEmpty }
    var title: String? { attrs["title"]?.nilIfEmpty }
    var value: String? { attrs["value"]?.nilIfEmpty }

    /// Parse "minX,minY,width,height" (integers) into a CGRect; nil if absent/malformed.
    var frame: CGRect? {
        guard let s = attrs["frame"] else { return nil }
        let parts = s.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 4 else { return nil }
        return CGRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
    }

    /// A one-line label for the outline row.
    var displayLabel: String {
        if let id = identifier { return "\(role)  #\(id)" }
        if let t = title { return "\(role)  “\(t)”" }
        if let v = value { return "\(role)  =\(v)" }
        return role
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
