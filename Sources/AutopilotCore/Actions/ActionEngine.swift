import Foundation
import CoreGraphics
import ApplicationServices

public struct ActionEngine {
    public init() {}

    public struct Chord { public var virtualKey: CGKeyCode; public var flags: CGEventFlags }

    /// Map a small set of letters to ANSI virtual key codes. Extend as needed.
    static let letterKeyCodes: [Character: CGKeyCode] = [
        "a":0,"s":1,"d":2,"f":3,"h":4,"g":5,"z":6,"x":7,"c":8,"v":9,
        "b":11,"q":12,"w":13,"e":14,"r":15,"y":16,"t":17,
        "o":31,"u":32,"i":34,"p":35,"l":37,"j":38,"k":40,"n":45,"m":46,
        "1":18,"2":19,"3":20,"4":21,"5":23,"6":22,"7":26,"8":28,"9":25,"0":29
    ]
    static let namedKeyCodes: [String: CGKeyCode] = [
        "return": 36, "enter": 36, "tab": 48, "space": 49, "delete": 51,
        "escape": 27, "left": 123, "right": 124, "down": 125, "up": 126
    ]

    public static func parseChord(_ s: String) throws -> Chord {
        let parts = s.lowercased().split(separator: "+").map(String.init)
        guard let keyToken = parts.last else { throw PlanError.decode("empty key chord") }
        var flags: CGEventFlags = []
        for mod in parts.dropLast() {
            switch mod {
            case "cmd", "command": flags.insert(.maskCommand)
            case "shift": flags.insert(.maskShift)
            case "opt", "option", "alt": flags.insert(.maskAlternate)
            case "ctrl", "control": flags.insert(.maskControl)
            default: throw PlanError.decode("unknown modifier: \(mod)")
            }
        }
        if let named = namedKeyCodes[keyToken] { return Chord(virtualKey: named, flags: flags) }
        if keyToken.count == 1, let code = letterKeyCodes[keyToken.first!] {
            return Chord(virtualKey: code, flags: flags)
        }
        throw PlanError.decode("unknown key: \(keyToken)")
    }

    /// Center point of an ElementRef for click/type/drag targeting.
    public func point(for ref: ElementRef) -> CGPoint? {
        switch ref {
        case .point(let p): return p
        case .ax(let el):
            guard let f = AXTree.frame(el) else { return nil }
            return CGPoint(x: f.midX, y: f.midY)
        }
    }

    /// Perform a step's action against a resolved element (when applicable).
    /// Returns nothing; throws on unrecoverable failures.
    public func perform(action: Action, args: ActionArgs?, ref: ElementRef?) throws {
        switch action {
        case .click:
            guard let ref, let p = point(for: ref) else { throw PlanError.decode("click needs a point") }
            EventSynthesizer.click(at: p)
        case .doubleClick:
            guard let ref, let p = point(for: ref) else { throw PlanError.decode("doubleClick needs a point") }
            EventSynthesizer.click(at: p, clickCount: 2)
        case .rightClick:
            guard let ref, let p = point(for: ref) else { throw PlanError.decode("rightClick needs a point") }
            EventSynthesizer.click(at: p, rightButton: true)
        case .press:
            guard case .ax(let el)? = ref else { throw PlanError.decode("press needs an AX element") }
            if !AXTree.press(el) { throw PlanError.decode("AX press action failed") }
        case .type:
            guard let text = args?.text else { throw PlanError.decode("type needs text") }
            if let ref, let p = point(for: ref) { EventSynthesizer.click(at: p) } // focus first
            EventSynthesizer.type(text)
        case .setValue:
            guard let text = args?.text, case .ax(let el)? = ref else { throw PlanError.decode("setValue needs AX element + text") }
            AXUIElementSetAttributeValue(el, kAXValueAttribute as CFString, text as CFString)
        case .keyPress:
            guard let keys = args?.keys else { throw PlanError.decode("keyPress needs keys") }
            let chord = try Self.parseChord(keys)
            EventSynthesizer.keyChord(virtualKey: chord.virtualKey, flags: chord.flags)
        case .scroll:
            EventSynthesizer.scroll(dx: Int32(args?.deltaX ?? 0), dy: Int32(args?.deltaY ?? 0))
        case .launch, .terminate, .waitFor, .screenshot, .assert, .wait, .menu, .drag:
            break // handled by PlanRunner, not here
        }
    }
}
