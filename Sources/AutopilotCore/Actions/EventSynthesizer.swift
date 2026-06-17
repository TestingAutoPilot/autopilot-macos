import Foundation
import CoreGraphics
import ApplicationServices

/// Synthesizes low-level input events via CoreGraphics.
public enum EventSynthesizer {
    public static func click(at point: CGPoint, clickCount: Int = 1, rightButton: Bool = false) {
        let button: CGMouseButton = rightButton ? .right : .left
        let down: CGEventType = rightButton ? .rightMouseDown : .leftMouseDown
        let up: CGEventType = rightButton ? .rightMouseUp : .leftMouseUp
        for _ in 0..<clickCount {
            let d = CGEvent(mouseEventSource: nil, mouseType: down, mouseCursorPosition: point, mouseButton: button)
            let u = CGEvent(mouseEventSource: nil, mouseType: up, mouseCursorPosition: point, mouseButton: button)
            d?.post(tap: .cghidEventTap)
            u?.post(tap: .cghidEventTap)
        }
    }

    /// Type a string as unicode keyboard events (works regardless of layout).
    public static func type(_ text: String) {
        for scalar in text.unicodeScalars {
            var ch = UniChar(scalar.value > 0xFFFF ? 0 : scalar.value)
            let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)
            let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)
            if scalar.value <= 0xFFFF {
                down?.keyboardSetUnicodeString(stringLength: 1, unicodeString: &ch)
                up?.keyboardSetUnicodeString(stringLength: 1, unicodeString: &ch)
            }
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
        }
    }

    /// Press a key chord, e.g. virtualKey for "s" with .maskCommand.
    public static func keyChord(virtualKey: CGKeyCode, flags: CGEventFlags) {
        let down = CGEvent(keyboardEventSource: nil, virtualKey: virtualKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: nil, virtualKey: virtualKey, keyDown: false)
        down?.flags = flags
        up?.flags = flags
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    public static func scroll(dx: Int32, dy: Int32) {
        let e = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: dy, wheel2: dx, wheel3: 0)
        e?.post(tap: .cghidEventTap)
    }
}
