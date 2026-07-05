// Tiny capture helper for scripts/capture-guide-screenshots.sh.
// Two subcommands, both dependency-free (uses only system frameworks):
//
//   winid <pid>                 -> prints the CGWindowID of the largest on-screen
//                                  normal window owned by <pid> (empty if none).
//   render <title> <out.png> <<<body   -> renders terminal-styled text to a PNG,
//                                  reading the body from stdin. So the REAL terminal
//                                  is never photographed.
//
// Window pixels themselves are captured by `screencapture -l<id>` in the shell
// script (window-scoped only — never the whole display), so nothing here grabs the
// screen. This helper only *finds* the id and *renders text*.
import Foundation
import CoreGraphics
import AppKit

func windowID(forPID pid: pid_t) -> CGWindowID? {
    let opts: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    guard let infos = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] else { return nil }
    var best: (id: CGWindowID, area: CGFloat)?
    for w in infos {
        guard let owner = w[kCGWindowOwnerPID as String] as? pid_t, owner == pid else { continue }
        let layer = (w[kCGWindowLayer as String] as? Int) ?? 0
        guard layer == 0 else { continue }                       // normal windows only
        guard let b = w[kCGWindowBounds as String] as? [String: Any],
              let width = b["Width"] as? CGFloat, let height = b["Height"] as? CGFloat,
              let num = w[kCGWindowNumber as String] as? CGWindowID else { continue }
        let area = width * height
        if best == nil || area > best!.area { best = (num, area) }
    }
    return best?.id
}

func renderText(title: String, body: String, to path: String) {
    let lines = (["$ " + title] + body.split(separator: "\n", omittingEmptySubsequences: false).map(String.init))
    let font = NSFont(name: "Menlo", size: 13) ?? NSFont.userFixedPitchFont(ofSize: 13)!
    let pad: CGFloat = 16, lh: CGFloat = 18, width: CGFloat = 860
    let height = pad * 2 + lh * CGFloat(lines.count)
    let img = NSImage(size: NSSize(width: width, height: height))
    img.lockFocus()
    NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.14, alpha: 1).set()
    NSRect(x: 0, y: 0, width: width, height: height).fill()
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(calibratedRed: 0.82, green: 0.84, blue: 0.87, alpha: 1),
    ]
    for (i, ln) in lines.enumerated() {
        let y = height - pad - lh * CGFloat(i + 1)
        (ln as NSString).draw(at: NSPoint(x: pad, y: y), withAttributes: attrs)
    }
    img.unlockFocus()
    guard let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write("render: failed to make PNG\n".data(using: .utf8)!); exit(1)
    }
    try? png.write(to: URL(fileURLWithPath: path))
}

let args = CommandLine.arguments
guard args.count >= 2 else { FileHandle.standardError.write("usage: winid <pid> | render <title> <out>\n".data(using: .utf8)!); exit(2) }
switch args[1] {
case "winid":
    guard args.count == 3, let pid = pid_t(args[2]) else { exit(2) }
    if let id = windowID(forPID: pid) { print(id) }
case "render":
    guard args.count == 4 else { exit(2) }
    let body = String(data: FileHandle.standardInput.readDataToEndOfFile(), encoding: .utf8) ?? ""
    renderText(title: args[2], body: body, to: args[3])
default:
    FileHandle.standardError.write("unknown subcommand \(args[1])\n".data(using: .utf8)!); exit(2)
}
