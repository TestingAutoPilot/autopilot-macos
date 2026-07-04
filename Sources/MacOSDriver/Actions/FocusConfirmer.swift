import Foundation

/// Confirms a control is actually focused/editing before `type` sends keystrokes.
///
/// `type` used to fire focus events (a click + a kAXFocusedAttribute write) and
/// type IMMEDIATELY, with no read-back. That silently dropped text in two cases
/// medit's field report reproduced:
///   - a freshly-opened panel field, where focus races the window becoming key; and
///   - a field re-edited after a prior `commit`/Return, where AppKit tore down the
///     field editor — setting kAXFocusedAttribute marks the control focused but does
///     not re-begin editing, so keystrokes land nowhere.
///
/// The confirmer polls the focus state, and when a plain focus attempt does not
/// take it escalates to an AXPress (which re-arms the field editor / begins
/// editing on a text field). It reports failure so the caller can throw instead
/// of typing into the void.
///
/// The logic is pure and fully injectable (no AX / CGEvent calls of its own) so
/// it is deterministically unit-testable without a WindowServer.
enum FocusConfirmer {
    /// - Parameters:
    ///   - maxAttempts: how many focus/press rounds to try before giving up.
    ///   - readFocused: reads the element's focused state; `nil` when the element
    ///     does not expose kAXFocusedAttribute at all.
    ///   - attemptFocus: the plain focus attempt (click + set kAXFocusedAttribute).
    ///   - beginEditing: the escalation (AXPress) that begins editing; returns
    ///     whether the press action itself succeeded.
    ///   - settle: a short pause between an action and re-reading focus.
    /// - Returns: `true` if the element is focused (or its focus state is
    ///   unreadable, which we treat as "proceed"); `false` if focus never took.
    static func ensureFocused(
        maxAttempts: Int,
        readFocused: () -> Bool?,
        attemptFocus: () -> Void,
        beginEditing: () -> Bool,
        settle: () -> Void
    ) -> Bool {
        // Already first responder — nothing to do.
        if readFocused() == true { return true }

        for attempt in 0..<max(1, maxAttempts) {
            // First round: the plain focus attempt (click + kAXFocusedAttribute).
            // Later rounds: escalate to an AXPress, which re-begins editing on a
            // field whose editor was torn down by a prior commit.
            if attempt == 0 {
                attemptFocus()
            } else {
                _ = beginEditing()
            }
            settle()

            switch readFocused() {
            case .some(true):
                return true
            case .none:
                // The element does not report focus at all (never has). We cannot
                // confirm, but must not hard-fail it — proceed as the pre-fix code
                // did for such elements (the focus attempt is the best we can do).
                return true
            case .some(false):
                continue
            }
        }
        return false
    }
}
