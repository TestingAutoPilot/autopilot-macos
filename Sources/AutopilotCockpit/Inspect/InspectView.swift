import SwiftUI
import AppKit
import AutopilotCore

/// Inspect mode: live AX tree outline + element detail + selector copy/suggest.
struct InspectView: View {
    @Bindable var engine: CockpitEngine
    @State private var selection: AXNode.ID?
    @State private var search = ""

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                HStack {
                    TextField("Search role / id / title", text: $search)
                        .textFieldStyle(.roundedBorder)
                    Button("Refresh") { engine.refreshTree() }
                }.padding(8)
                Divider()
                List(selection: $selection) {
                    OutlineGroup(filteredRoots, children: \.childrenOrNil) { node in
                        Text(node.displayLabel).tag(node.id)
                    }
                }
                if engine.treeTruncated {
                    Text("Tree truncated (node cap reached)")
                        .font(.caption).foregroundStyle(.orange).padding(4)
                }
            }
            .frame(minWidth: 320)

            ElementDetail(node: selectedNode, engine: engine)
                .frame(minWidth: 280)
        }
        .overlay {
            if engine.attached == nil {
                ContentUnavailableView("No app attached", systemImage: "cursorarrow.rays",
                                       description: Text("Choose a target above."))
            }
        }
    }

    private var filteredRoots: [AXNode] {
        guard !search.isEmpty else { return engine.roots }
        func matches(_ n: AXNode) -> Bool {
            n.displayLabel.localizedCaseInsensitiveContains(search) || n.children.contains(where: matches)
        }
        return engine.roots.filter(matches)
    }

    private var selectedNode: AXNode? {
        func find(_ nodes: [AXNode]) -> AXNode? {
            for n in nodes { if n.id == selection { return n }; if let f = find(n.children) { return f } }
            return nil
        }
        return find(engine.roots)
    }
}

/// Right-hand detail + copy-selector for the selected node.
struct ElementDetail: View {
    let node: AXNode?
    let engine: CockpitEngine

    var body: some View {
        if let node {
            Form {
                LabeledContent("Role", value: node.role)
                if let id = node.identifier { LabeledContent("Identifier", value: id) }
                if let t = node.title { LabeledContent("Title", value: t) }
                if let v = node.value { LabeledContent("Value", value: v) }
                if let f = node.frame {
                    LabeledContent("Frame", value: "\(Int(f.minX)),\(Int(f.minY)) \(Int(f.width))×\(Int(f.height))")
                }
                HStack {
                    Button("Copy selector") { copySelector(for: node) }
                    Button("Use as selector →") { engine.pendingSelector = engine.selector(for: node) }
                        .help("Send this selector to Author to fill a step's target")
                }
            }.formStyle(.grouped)
        } else {
            ContentUnavailableView("No element selected", systemImage: "square.dashed")
        }
    }

    /// Copy the node's preferred selector (see CockpitEngine.selector(for:)) to
    /// the pasteboard as JSON.
    private func copySelector(for node: AXNode) {
        let selector = engine.selector(for: node)
        let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys, .prettyPrinted]
        if let data = try? enc.encode(selector), let json = String(data: data, encoding: .utf8) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(json, forType: .string)
        }
    }
}
