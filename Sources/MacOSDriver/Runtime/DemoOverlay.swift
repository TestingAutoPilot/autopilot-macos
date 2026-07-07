import Foundation
import AppKit

/// Demo-mode on-screen overlays: a highlight ring around an element and a caption
/// banner. Used only when a plan runs in demo mode (RunOptions.demoMode) to turn a
/// deterministic test into a watchable screencast. Never used on the test path.
///
/// Overlays are borderless, transparent, click-through, screen-level NSWindows.
/// They are created/shown on the MAIN thread (AppKit requirement) and auto-dismiss
/// after `holdMs` via a timer, so a demo step shows its overlay without the runner
/// blocking on it. Frames arrive in AX/global coordinates (top-left origin); AppKit
/// windows use bottom-left origin, so we flip Y against the primary screen height.
public enum DemoOverlay {

    /// Draw a glow ring around `axFrame` (top-left-origin global coords) for `holdMs`.
    public static func highlight(axFrame: CGRect, holdMs: Int) {
        let ns = flip(axFrame).insetBy(dx: -6, dy: -6)
        onMain {
            let win = makeWindow(frame: ns)
            let ring = RingView(frame: NSRect(origin: .zero, size: ns.size))
            win.contentView = ring
            present(win, holdMs: holdMs)
        }
    }

    /// Show a caption banner with `text` at `position` ("top"/"bottom"/"center")
    /// for `holdMs` on the primary screen.
    public static func caption(text: String, position: String, holdMs: Int) {
        onMain {
            guard let screen = NSScreen.main else { return }
            let vis = screen.frame
            let width = min(max(vis.width * 0.6, 320), vis.width - 80)
            let height: CGFloat = 64
            let x = vis.midX - width / 2
            let y: CGFloat
            switch position {
            case "top":    y = vis.maxY - height - 80
            case "center": y = vis.midY - height / 2
            default:       y = vis.minY + 80          // "bottom"
            }
            let frame = NSRect(x: x, y: y, width: width, height: height)
            let win = makeWindow(frame: frame)
            let banner = CaptionView(frame: NSRect(origin: .zero, size: frame.size))
            banner.text = text
            win.contentView = banner
            present(win, holdMs: holdMs)
        }
    }

    // MARK: - Window plumbing

    /// A borderless, transparent, click-through window that floats above everything.
    private static func makeWindow(frame: NSRect) -> NSWindow {
        let win = NSWindow(contentRect: frame, styleMask: .borderless,
                           backing: .buffered, defer: false)
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.ignoresMouseEvents = true               // click-through: never steals input
        win.level = .screenSaver                     // above normal + floating windows
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        return win
    }

    /// Show the window, then dismiss it after `holdMs` (min 400ms so a 0/tiny hold is
    /// still visible). Non-blocking — returns immediately; a timer closes the window.
    private static func present(_ win: NSWindow, holdMs: Int) {
        win.orderFrontRegardless()
        let ms = max(holdMs, 400)
        // Retain the window until the timer fires (the closure holds the reference).
        Timer.scheduledTimer(withTimeInterval: Double(ms) / 1000.0, repeats: false) { _ in
            win.orderOut(nil)
        }
    }

    /// Run `body` on the main thread. If already on main, run inline (so a main-thread
    /// caller — e.g. the Cockpit's own thread — sees the overlay synchronously created);
    /// otherwise hop async so a background runner thread never blocks.
    private static func onMain(_ body: @escaping () -> Void) {
        if Thread.isMainThread { body() } else { DispatchQueue.main.async(execute: body) }
    }

    /// Flip a top-left-origin global rect to AppKit's bottom-left-origin space.
    private static func flip(_ r: CGRect) -> NSRect {
        let h = NSScreen.screens.first?.frame.height ?? r.maxY
        return NSRect(x: r.minX, y: h - r.maxY, width: r.width, height: r.height)
    }
}

// MARK: - Views

/// A rounded glow ring drawn inside its bounds.
private final class RingView: NSView {
    override var isFlipped: Bool { false }
    override func draw(_ dirtyRect: NSRect) {
        let inset = bounds.insetBy(dx: 3, dy: 3)
        let path = NSBezierPath(roundedRect: inset, xRadius: 8, yRadius: 8)
        path.lineWidth = 4
        // A bright accent ring with a soft outer glow.
        NSColor.systemYellow.withAlphaComponent(0.95).setStroke()
        let glow = NSShadow()
        glow.shadowColor = NSColor.systemYellow.withAlphaComponent(0.8)
        glow.shadowBlurRadius = 12
        glow.shadowOffset = .zero
        NSGraphicsContext.saveGraphicsState()
        glow.set()
        path.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }
}

/// A pill caption banner with centered text.
private final class CaptionView: NSView {
    var text: String = "" { didSet { needsDisplay = true } }
    override var isFlipped: Bool { false }
    override func draw(_ dirtyRect: NSRect) {
        let bg = NSBezierPath(roundedRect: bounds, xRadius: 12, yRadius: 12)
        NSColor.black.withAlphaComponent(0.78).setFill()
        bg.fill()
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineBreakMode = .byTruncatingTail
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 22, weight: .semibold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: style,
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        let rect = NSRect(x: bounds.minX + 16,
                          y: bounds.midY - size.height / 2,
                          width: bounds.width - 32, height: size.height)
        (text as NSString).draw(in: rect, withAttributes: attrs)
    }
}
