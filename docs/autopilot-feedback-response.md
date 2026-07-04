# Response to medit's AutoPilot Field Report

_This is the AutoPilot-side triage of the field report medit maintains at
`medit/docs/autopilot-feedback.md`. Each finding is marked **FIXED** (already
addressed in the current code — with the source that resolves it), **DONE THIS
PASS** (addressed by the changes committed alongside this doc), or **OPEN**
(filed, not yet done). The medit report spans Rounds 1–3 (commits `3d7b5cb` →
`7a577f1` → `76e3261`) up through medit 2.7.5; a large fraction of the early
P0/P1 items were fixed in the intervening releases and the report simply
predates those fixes._

Verified against `autopilot-core` `main` and `autopilot-macos` `main` on
2026-07-03.

---

## Already FIXED in current code (report predates the fix)

| Finding (report ref) | Resolved by |
|---|---|
| **P0 — value/property asserts are one-shot; only presence polls** (Round 1 TL;DR #1) | `AssertionEngine.pollEvaluate(op:expected:…)` — `runAssert`/`runAssertPixel`/`runAssertRegion` in `PlanRunner` poll the comparison on the same timeout/interval as presence, capturing artifacts only after the retry loop expires. |
| **P0 — `click` can't drive menus; no menu-press** (Round 1 #2, R1 P0) | `menu` action + `AXPress` path: `Action.menu` → `MenuNavigator.selectPath`, and `Action.press` → `kAXPressAction`. |
| **P1 — no app activation / key-window wait before input** (Round 1 #5) | `PlanRunner.run` calls `driver.activate(app, timeoutMs:intervalMs:)` (polls `NSRunningApplication.isActive`) + a settle before the first step; `AppLauncher.activate` implements the poll. |
| **P2 — `terminate` then relaunch races; two instances coexist** (Round 1, medit 2.7.x "AX-linger race", the single most-repeated ask) | `AppLauncher.launch` calls `waitForExistingInstancesToExit(of:bundleId:timeout:3.0)` — polls until prior instances leave the process table and force-terminates stragglers before the new launch. Every consumer (CLI single, `run <dir>` suite, cockpit, tests) gets this. |
| **P1 — no comma / punctuation in the key map** (Round 1 #3, R1 P1) | `KeyMap` includes the full ANSI punctuation set (`,`=43, `.`, `/`, `;`, `'`, `[`, `]`, `\`, `` ` ``, `-`, `=`, …). `cmd+,` works. |
| **R2-1 — `type`'s focus-click breaks an already-focused field** | `ActionArgs.focus` (`focus:false`) honored in `ActionEngine`: skips the focus-click and types into the already-focused element; also sets `kAXFocusedAttribute` for determinism. |
| **R2-2 — checkbox / numeric AXValue unreadable** | `AXTree.string`/`valueString` stringify `NSNumber`/`CFBoolean` AX values (0/1 → "0"/"1"); the `CFNumberIsFloatType` fix keeps `1.0`→"1.0". Checkbox round-trip asserts work. |
| **P1 — ambiguous selector error says only "2"; can't disambiguate** (Interface P1) | `TargetingError.ambiguous(selector:count:matches:)` lists the matches; `Selector.index` and `Selector.within` provide the disambiguators the report asked for. |
| **`count` assertion missing** (multi-window `AXWindow` count) | `AssertProperty.count` + `runAssert`'s count branch (`driver.matchCount`). |
| **R3-1 — `dump_axtree` reports a phantom window, not the running instance** (P0) | `dump-axtree`, `find`, `suggest` all take `--pid` and attach to that exact process (`Inspect.attach(app:pid:)` → `AXTree.application(pid:)`); attach mode never launches. The `--pid` escape hatch the report explicitly asked for exists. |
| **Include base-dir underspecified** (behavior, not docs) | Behavior is correct (`PlanParser` resolves includes against the including file's dir); the *doc* gap is addressed below. |
| **NICE — machine-readable one-line summary** | `Reporter.summaryLine` prints a one-line PASS/FAIL summary to stderr; `--json` emits `report.json`. |

**Net:** the early P0/P1 reliability items — the ones the report said would take
suite reliability "from ~85% to ~100%" — are all in. The remaining actionable
items are documentation gaps and two genuinely-missing runtime primitives.

---

## DONE THIS PASS (committed alongside this doc)

### AUTHORING.md doc-gap closure
The report's biggest remaining category was **documentation defects** — behaviors
that are real and correct but undocumented, so an author working within the docs
couldn't know them. Added to `docs/AUTHORING.md`:

- **Pop-up button (`AXPopUpButton`) selection recipe** (D1): `press` to open, then
  `click` an `{role: AXMenuItem, title: …}` — `type` does not select a popup value.
- **Pop-up re-open / focus-reset constraint** (D2): move focus off the control
  between opens.
- **Same-field re-edit caveat** (D3) and **`setValue` vs `type` semantics** (P2 /
  D4): `setValue` sets the AX value only and fires no action; `type` (with
  `commit`) drives the control's end-editing path.
- **Cell-based control identifier note** (D5): for cell-based
  `NSButton`/`NSTextField`/`NSPopUpButton`, the identifier must be set on the
  *cell* to surface in the AX tree.
- **AppKit → AX role cheat sheet** (`NSTextView`→`AXTextArea`, `NSOutlineView`→
  `AXOutline`, rows→`AXRow`/`AXCell`, `NSRulerView`→not addressable, buttons→
  `AXButton`/`AXCheckBox`, `NSPopUpButton`→`AXPopUpButton`).
- **"What is NOT observable" box**: menu checkmarks (assert the side effect),
  ruler/gutter views, layout-manager temporary attributes, anything drawn without
  an AX element.
- **`focus:false` rule** and the search-field (`NSSearchField`) note.
- **Include base-dir rule** with a nested example ("relative to the file that
  declares them").
- **Full supported key list + punctuation.**
- **Clean-state recipe for document-based apps** (state restoration + autosave).

### Menu-item discovery (feature A) — the disabled-item gap (medit 2.7.4 P2)
`menu` could not reach an item that is disabled at menu-open time (e.g. "Column
Selection Mode"), and there was no way to *list* what a menu contains. Added:

- **Core:** `AppDriver.listMenu(path:app:) -> [MenuItemInfo]` where
  `MenuItemInfo { title: String; enabled: Bool; hasSubmenu: Bool; markChar: String? }`
  — a neutral, platform-agnostic menu descriptor.
- **macOS:** `MacOSDriver.listMenu` walks the same menu path as `selectPath` and
  reports **every** item including disabled ones, with `enabled` and the
  `AXMenuItemMarkChar` (so a menu-toggle's ✓ state becomes observable — closes the
  "menu state is not observable" gap for the discovery path).
- **CLI:** `autopilot menu --pid <pid> --path "View" ["Show Markdown Preview"]`
  lists items as JSON.

### Clipboard assertion primitive (feature B) — D6
There was no way to read the system pasteboard, so "copy X" could only be verified
indirectly by pasting. Added:

- **Core:** `AssertProperty.clipboard` — a target-less assertion property whose
  "actual" is the current system clipboard text; works with the existing
  `equals`/`contains`/`matches` ops and polls like any other assert.
- **macOS:** `MacOSDriver.readClipboard()` reads `NSPasteboard.general` string
  contents; `PlanRunner` routes a `clipboard`-property assert with no target to it.

---

## OPEN — filed, not addressed this pass

These are real but were scoped out of this pass (documented so they are not lost):

- **Screenshot sharp edges** (SC-1..SC-5, medit 2.6.2 / docs round): silent
  element-screenshot failure with no `message`; frontmost-gating for WKWebView /
  web-area captures; thin-element crop emptiness; `snapshot` reference-write
  failure; negative / secondary-display window origins in the capture path. These
  want a focused pass on `Screenshot`/`ScreenCapture` in `MacOSDriver`.
- **Cross-process system alerts** (D7 / M2): a modal owned by `CoreServicesUIAgent`
  (LaunchServices' permission-denied alert) is invisible to a target-attached run
  and steals focus. Decide: document as out-of-scope with the recommended
  out-of-band `osascript` cleanup, or add a primitive to observe/dismiss
  foreign-process alerts. (M1/M2 themselves are medit bugs, not AP's.)
- **`dump_axtree` filtering** (NICE): "interactive only" / "subtree under role" /
  "omit menu bar" flags for large trees. (`suggest` already gives interactive
  elements; a filter flag on the raw dump is the ask.)
- **Chord `+`-as-final-key** (R Key P2) and **distinct "unsupported key" exit code**
  vs. a plan-decode error (NICE).

---

_Filed by the AutoPilot session against `feature/ap-feedback`. Nothing here is a
medit change; the medit report file is read-only to this lane._
