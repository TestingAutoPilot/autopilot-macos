import CoreGraphics

/// Reconstructs display nesting from AXTree's flat pre-order snapshot.
///
/// The snapshot is a depth-first pre-order list with no parent pointers. We use
/// frame containment: each node's parent is the nearest PRECEDING node whose
/// frame fully contains this node's frame (pre-order guarantees a container is
/// emitted before its contents). Nodes with no frame, or no containing
/// predecessor, are roots. Pure and deterministic.
enum TreeBuilder {
    static func build(from nodes: [[String: String]]) -> [AXNode] {
        let flat = nodes.enumerated().map { AXNode(index: $0.offset, attrs: $0.element) }
        // Precompute frames once.
        let frames: [CGRect?] = flat.map { $0.frame }

        // parentOf[i] = index of chosen parent, or nil for a root.
        var parentOf = [Int?](repeating: nil, count: flat.count)
        // childrenOf[i] = indices of direct children, in original (pre-order) order.
        var childrenOf = [[Int]](repeating: [], count: flat.count)

        for i in flat.indices {
            guard let childFrame = frames[i] else { continue } // frameless -> root
            // Nearest preceding container.
            var j = i - 1
            while j >= 0 {
                if let pf = frames[j], pf.contains(childFrame) {
                    parentOf[i] = j
                    childrenOf[j].append(i)
                    break
                }
                j -= 1
            }
        }

        // Assemble recursively from each root, so a node carries its full subtree.
        func assemble(_ i: Int) -> AXNode {
            var node = flat[i]
            node.children = childrenOf[i].map(assemble)
            return node
        }

        return flat.indices.filter { parentOf[$0] == nil }.map(assemble)
    }
}
