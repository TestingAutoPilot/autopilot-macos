import SwiftUI
import AppKit

/// Pure loaders for a step's on-disk artifacts (written by PlanRunner).
enum ArtifactLoader {
    static func image(atPath path: String?) -> NSImage? {
        guard let path, FileManager.default.fileExists(atPath: path) else { return nil }
        return NSImage(contentsOfFile: path)
    }
    static func axDumpText(atPath path: String?) -> String? {
        guard let path, FileManager.default.fileExists(atPath: path),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

/// Right-hand pane in Run: the selected step's failure screenshot + AX dump.
struct ArtifactPane: View {
    let screenshot: String?
    let axDump: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let img = ArtifactLoader.image(atPath: screenshot) {
                Image(nsImage: img).resizable().scaledToFit()
                    .frame(maxHeight: 260).border(.secondary)
            }
            if let text = ArtifactLoader.axDumpText(atPath: axDump) {
                Text("AX dump").font(.headline)
                ScrollView {
                    Text(text).font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if screenshot == nil && axDump == nil {
                ContentUnavailableView("No artifacts", systemImage: "photo",
                    description: Text("Passing steps produce no failure artifacts."))
            }
            Spacer()
        }.padding(8)
    }
}
