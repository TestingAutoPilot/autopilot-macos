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
Much of the report's "documentation defects" category was **already documented**
in the current `docs/AUTHORING.md` — §15 (AppKit → AX cheat sheet), §16 (What is
NOT observable, incl. menu checkmarks → assert the side effect), §17
(Troubleshooting: `focus:false`, `setValue`-vs-`type`, include base-dir rule,
punctuation, checkbox numeric value, menu-can't-be-clicked). Those D-items needed
no change. The genuinely-missing pieces added this pass:

- **Pop-up button (`AXPopUpButton`) selection recipe** (D1) — a new subsection
  under §4: `press` to open, then `click` an `{role: AXMenuItem, title: …}`;
  `type` does not select a popup value. With a `value` assert to confirm.
- **Pop-up re-open / focus-reset constraint** (D2) — same subsection: move focus
  off the control between opens.
- **Cell-based control identifier note** (D5) — added to §8: for cell-based
  `NSButton`/`NSTextField`/`NSPopUpButton`, the identifier must also be set on the
  control's **cell** to surface in the AX tree.

(New doc entries for the two runtime features below are added alongside them.)

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

### Second pass — the remaining items, now closed

- **SC-1 — silent screenshot failure.** The runner already messaged the
  element-crop and target-didn't-resolve fallbacks; closed the last silent path so
  a full-display capture failure ALWAYS carries a reason (names Screen Recording
  when that's the cause). Tests: `ScreenshotMessageTests`.
- **SC-2 / SC-5 — negative / secondary-display origins.** Already fixed by the
  ScreenCaptureKit rewrite: `ScreenCapture` picks the display whose frame
  *intersects* the rect (incl. negative-origin secondaries) and converts to
  display-local coords. Verified by inspection; no code change needed.
- **`snapshot` reference-write failure.** Screen Recording is already checked
  before the write, so a bare "failed to write reference" was misleading — it now
  reports whether the destination directory is writable vs. the capture returning
  no image.
- **WKWebView / web-area capture blank unless frontmost.** `Screenshot.captureElement`
  now detects an `AXWebArea` (self or ancestor) and, if the owning app isn't
  frontmost, fails with a clear reason instead of writing a blank PNG. (Verified by
  inspection — the TestHostApp fixture has no WKWebView.)
- **`dump-axtree` filtering.** Added `--under-role <role>` (only the first matching
  element's subtree, by frame containment) and `--omit-menubar` (drop menu-bar/menu
  nodes). Pure `TreeFilter` + `TreeFilterTests`; verified live (159 → 74 → 72 nodes).
- **Chord `+`-as-final-key + distinct unsupported-key exit.** `cmd+plus` was already
  the supported form and `PlanError.unsupportedKey` was already a distinct case; the
  gap was the CLI collapsing all plan errors to exit 2. `run` now exits **4** for an
  unsupported key (2 stays for invalid plans). Tests: `CLITests`.
- **D7 — cross-process system alerts.** Reclassified from "document as out-of-scope"
  to a real feature: new `autopilot dismiss-alert <app|--pid>` attaches to the
  alert's OWNING process (e.g. `CoreServicesUIAgent`) and presses a button (OK /
  Close / Cancel / Don't Save / Dismiss, or `--button`). **Verified live** by
  dismissing a dialog owned by a separate `System Events` process. A `run` plan's
  steps still can't target another process's window — invoke this out-of-band
  (e.g. a suite runner between plans).

### Third pass — the two runtime items medit's branch re-validation surfaced

medit validated `feature/ap-feedback` and reported two AutoPilot-runtime items the
branch had **not** closed (plus two minor caveats). Both are the same root cause and
are now fixed.

- **D3 — same text field re-edited twice in one run silently drops the second edit.**
  **FIXED.** Root cause: `type` fired focus events (a click + a `kAXFocusedAttribute`
  write) and typed IMMEDIATELY, with no read-back. On a field re-edited after a prior
  `commit`/Return, AppKit had torn down the field editor and resigned first responder;
  a bare `kAXFocusedAttribute` write marks the control focused but does **not** re-begin
  editing, so the keystrokes landed nowhere. `type` now **confirms focus before typing**
  and **escalates to an `AXPress`** (which re-arms the field editor / begins editing)
  when a plain focus attempt does not take. The pure decision logic lives in
  `FocusConfirmer` (headless-unit-tested: `FocusConfirmerTests`).
  **Verified live against the medit Debug build** with medit's exact repro
  (`settings.tabWidth` set 6 then 3): pre-fix the run failed `check2` with
  `expected=3 actual=6` (the second edit dropped, exactly as reported); post-fix the
  same plan is 6/6 PASS. (The single-window TestHostApp fixture does not reproduce D3
  — its plain re-click re-focuses the field — so the fixture test
  `sameFormatterFieldReEditsTwiceInOneRun` is coverage, not the D3 guard; the escalation
  logic is guarded by `FocusConfirmerTests` and the fix is proven by the medit repro.)
- **Freshly-opened panel field not editable even after `waitFor present`.** **FIXED by
  the same change.** `waitFor present` resolves when the element exists in the AX tree,
  which can precede it becoming first-responder on a just-opened panel — so the old
  fire-and-forget first `type` raced the panel and dropped the text (~3/5 on medit's
  host). The focus-confirm loop now **polls readiness and re-attempts** instead of firing
  once, so `type` only sends keystrokes once the field is genuinely focused. (This host
  is fast enough that the readiness race did not reproduce here — 5/5 both pre- and
  post-fix on the medit Debug build — but the confirm loop is the correct mitigation and
  is demonstrably harmless: existing live typing tests, incl. `focus:false` search-field
  typing, still pass.)
- **Caveat — `dismiss-alert` timing:** the LaunchServices modal self-expires in
  ~2–10 s, so `dismiss-alert` only succeeds while it is up ("No matching button found"
  after). This is inherent — invoke it immediately after the denied-file plan.
  Documented as a usage note, not a code change.
- **Caveat — cold `menu` `markChar`:** a checked item's `AXMenuItemMarkChar` is only
  populated after AppKit's `validateMenuItem` runs, i.e. after the menu is opened, so a
  cold `menu` dump reads it empty. This is the AppKit constraint the report itself notes;
  `menu` surfaces the item + its `enabled` flag (the discovery gap), and toggle state is
  best asserted via the app's own side-effect surface.

### Fourth pass — the single-plan coverage gaps medit flagged

medit noted five capabilities its self-contained plans couldn't cover. Three were
real AutoPilot capability gaps; two are the existing `attach:true` pattern or an
inherent single-plan limit. The real gaps are now closed.

- **Overwrite mode needs the Insert key — no `insert` in the key map.** **FIXED.**
  Added `insert` (and its AppKit `help` alias) to the chord vocabulary, mapped to
  `kVK_Help` (114). `keyPress` with `"insert"` now toggles an editor's overwrite
  mode. Tests: `ChordValidatorTests` (core), `KeyChordParseTests` (macos). Design in
  the same key extension as the punctuation keys.
- **Reload banner (external file-change mid-run) + Save disk-content verification.**
  **FIXED by the new `exec` step.** A plan step can now run a shell command
  (`command`, via `/bin/sh -c`) or an argv array (`argv`, no shell), capturing
  stdout/stderr/exitCode. A **bare** `exec` is a setup/teardown lever (always passes,
  exit ignored) — use it to write/modify a file on disk mid-plan and trigger the
  app's file-watcher (reload banner). An `exec` **with an assert** on
  `stdout`/`stderr`/`exitCode` verifies a side effect — e.g. `cat` the saved file and
  assert its bytes (Save verification). Bounded by `timeoutMs` (a hung command is
  killed + fails). Execution is in the macOS driver (`ProcessRunner` via
  `Foundation.Process`); core stays platform-pure (defaulted `AppDriver.runProcess`).
  Tests: `PlanParserTests` (exactly-one-of command/argv; target-less exec asserts),
  `RunExecTests` (bare-passes-on-nonzero; assert gates; launch-failure fails),
  `ProcessRunnerTests` (real Process: stdout/argv/nonzero/stderr/launch-fail/timeout/
  cwd), plus a live end-to-end (`execRoundTripsThroughRealDriver`) and a CLI proof.
  See AUTHORING §5a. Design spec: `docs/specs/2026-07-04-exec-step-design.md`.
- **Find-in-All-Tabs / Print (separate-process panels).** Partly the D7 cross-process
  boundary (a `run` plan's steps can't target another process's window) — use
  `dismiss-alert` / the `attach:true` two-phase pattern, and `exec` to stage state.
- **The "two-phase attach:true plan"** medit named is the existing intended pattern,
  not a gap — attach to already-arranged state instead of relaunching.

## OPEN — genuinely not fixable (laws of physics, not defects)

- **Exact screenshot hues / pixel-perfect visual state.** Colors are
  display/theme/GPU-dependent. AutoPilot already handles this correctly with
  tolerance-based `assertPixel`/`assertRegion` and `snapshot` diffing with a
  `maxDiff` — the right tools; there is nothing to "fix." Prefer the app's own
  snapshot tests for dense pixel-perfect checks.

(M1/M2 in the medit report are medit's own bugs, not AutoPilot's.)

---

_Filed by the AutoPilot session against `feature/ap-feedback`. Nothing here is a
medit change; the medit report file is read-only to this lane._
