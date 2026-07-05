import Testing
@testable import MacOSDriver

/// Pure, deterministic tests for the focus-confirmation logic that `type` uses
/// before sending keystrokes. The bug these guard against: `type` fired focus
/// events (click + set kAXFocusedAttribute) then typed IMMEDIATELY without
/// confirming focus took — so a freshly-opened panel field (focus races the
/// window becoming key) or a field re-edited after a prior `commit`/Return (the
/// field editor was torn down; setting kAXFocusedAttribute marks the control
/// focused but does not re-begin editing) silently dropped the text.
///
/// The confirmer polls focus, escalates to an AXPress (which re-arms the field
/// editor / begins editing) when a plain focus attempt doesn't take, and reports
/// failure so the caller can throw instead of typing into the void.
@Suite struct FocusConfirmerTests {

    @Test func alreadyFocusedSucceedsWithoutActing() {
        var attempts = 0
        var presses = 0
        let ok = FocusConfirmer.ensureFocused(
            maxAttempts: 5,
            readFocused: { true },              // already first responder
            attemptFocus: { attempts += 1 },
            beginEditing: { presses += 1; return false },
            settle: {}
        )
        #expect(ok)
        #expect(attempts == 0)                  // no focus click needed
        #expect(presses == 0)                   // no press escalation needed
    }

    @Test func focusTakesAfterAttemptSucceedsWithoutPress() {
        var focused = false
        var attempts = 0
        var presses = 0
        let ok = FocusConfirmer.ensureFocused(
            maxAttempts: 5,
            readFocused: { focused },
            attemptFocus: { attempts += 1; focused = true },   // click focuses it
            beginEditing: { presses += 1; return false },
            settle: {}
        )
        #expect(ok)
        #expect(attempts == 1)
        #expect(presses == 0)                   // plain focus was enough
    }

    @Test func escalatesToPressWhenAttemptDoesNotTake() {
        // The D3 re-edit case: a focus click / kAXFocusedAttribute write never
        // makes the field first responder again after a prior commit; an AXPress
        // begins editing. The confirmer must escalate and then succeed.
        var focused = false
        var attempts = 0
        var presses = 0
        let ok = FocusConfirmer.ensureFocused(
            maxAttempts: 5,
            readFocused: { focused },
            attemptFocus: { attempts += 1 },                    // click never focuses
            beginEditing: { presses += 1; focused = true; return true },  // press begins editing
            settle: {}
        )
        #expect(ok)
        #expect(attempts >= 1)                  // it tried the plain focus first
        #expect(presses == 1)                   // then escalated exactly once it needed to
    }

    @Test func returnsFalseWhenFocusNeverConfirms() {
        // The safety property: if nothing makes the element focused, the confirmer
        // reports failure so `type` throws instead of silently dropping the text.
        var attempts = 0
        var presses = 0
        let ok = FocusConfirmer.ensureFocused(
            maxAttempts: 3,
            readFocused: { false },             // never focuses
            attemptFocus: { attempts += 1 },
            beginEditing: { presses += 1; return false },
            settle: {}
        )
        #expect(!ok)
        #expect(attempts >= 1)
        #expect(presses >= 1)                   // it tried escalating too
    }

    @Test func unreadableFocusStateDoesNotBlockTyping() {
        // Some elements never expose kAXFocusedAttribute (read returns nil). We
        // must not hard-fail those — treat an unreadable focus state as "proceed"
        // after the focus attempt, matching the pre-fix behavior for such fields.
        let ok = FocusConfirmer.ensureFocused(
            maxAttempts: 3,
            readFocused: { nil },               // attribute not supported
            attemptFocus: {},
            beginEditing: { return false },
            settle: {}
        )
        #expect(ok)
    }
}
