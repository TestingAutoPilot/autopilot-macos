# Validation Checklist for medit — AutoPilot `feature/ap-feedback`

_A hand-off for the **medit** session to validate the AutoPilot changes that
close its field report. This lives in the AutoPilot lane; copy/adapt from it —
the AutoPilot session does not write into medit's tree._

**Status:** all changes are on the branch **`feature/ap-feedback`** in both
`autopilot-core` and `autopilot-macos`. They are **UNRELEASED** (behind the hard
release gate). Validate from the branch first; a release follows only after an
explicit "go".

**Latest additions (items 7–10 below):** D3 same-field-re-edit fix, freshly-opened-
panel first-`type` readiness fix, the `insert`/overwrite-mode key, and the new
`exec` step (mid-plan file-change + Save disk-content verification). Pull the branch
again — items 7–10 are newer than an earlier build you may have validated.

## How to build the branch to validate against

```bash
# In the AutoPilot macOS repo, on the feature branch:
cd autopilot-macos
git checkout feature/ap-feedback            # macOS side
# (its Package.swift already points at ../autopilot-core via a local path override,
#  so make sure the sibling autopilot-core is on feature/ap-feedback too:)
( cd ../autopilot-core && git checkout feature/ap-feedback )
swift build -c release                       # builds autopilot + AutopilotMCP + helpers
BIN="$(swift build -c release --show-bin-path)"   # $BIN/autopilot is the CLI to use below
```

Run `"$BIN/autopilot" doctor` first — Accessibility (and Screen Recording for the
visual items) must be granted to whatever launches the CLI.

---

## Part 1 — NEW capabilities to validate (each closes a report item)

### 1. Clipboard assertion (closes **D6**)
A `clipboard` assert reads the system pasteboard; it is **target-less** (omit
`target`). Replaces the indirect "paste into the editor and assert" pattern.

```jsonc
// e.g. after a copy step in a medit plan:
{ "id": "copied-line", "action": "assert", "level": "happyPath",
  "assert": { "property": "clipboard", "op": "contains", "expected": "the copied text" } }
```
**Validate:** a plan that copies known text then asserts `clipboard` passes; a
"copy with nothing selected leaves the clipboard unchanged" case can now be
asserted directly. Empty pasteboard reads as `""`.

### 2. Menu discovery incl. disabled items (closes **medit 2.7.4 P2**)
`autopilot menu <app> [--path …]` lists every item of a menu — **including
disabled ones** the old `menu` walker hid and nothing surfaced.

```bash
"$BIN/autopilot" menu <medit-bundle-or-path> --path Edit Text --pid <medit-pid>
```
**Validate:** **"Column Selection Mode"** now appears in the JSON with
`"enabled": false` (it was previously invisible). Each item reports `enabled`,
`hasSubmenu`, and `markChar` (the ✓ when checked — so a toggle's state is
observable from discovery). Note: a disabled item still can't be *invoked* by the
`menu` action; this makes it *visible* so you stop guessing.

### 3. Dismiss a cross-process system alert (closes **D7**)
`autopilot dismiss-alert <app|--pid> [--button]` attaches to the alert's **owning
process** and presses a button — for the LaunchServices permission-denied modal
that is owned by **`CoreServicesUIAgent`**, not medit, and is invisible to a
medit-attached run.

```bash
# Reproduce the denied-file case (edge-open-denied-file), then:
"$BIN/autopilot" dismiss-alert com.apple.coreservices.uiagent
# or target it precisely:  --pid <CoreServicesUIAgent-pid>  --button "OK"
```
**Validate:** the orphaned `CoreServicesUIAgent` alert that was contaminating
later screenshot-based plans in a suite run is cleared. With no `--button` it
tries OK / Close / Cancel / Don't Save / Dismiss. Invoke it **out-of-band** in
your suite runner between plans — a `run` plan's steps still can't target another
process's window.

### 4. dump-axtree filters (closes the "dump filtering" NICE)
Trim a large tree (medit's was ~270 nodes incl. the whole system menu bar):

```bash
"$BIN/autopilot" dump-axtree <medit> --pid <pid> --under-role AXWindow --omit-menubar
```
**Validate:** `--omit-menubar` drops menu-bar/menu nodes; `--under-role AXWindow`
keeps only the first window's subtree (drops the menu bar and any other windows).
Combine with `--interactive-only`. (Verified on the fixture: 159 → 74 → 72 nodes.)

### 5. Pop-up button selection recipe (closes **D1/D2**) — docs, verify it works
The documented recipe (`docs/AUTHORING.md`, under §4): `press` the popup to open
it, then `click` an `{ "role": "AXMenuItem", "title": "…" }`; assert the popup's
`value` to confirm. **Re-opening** a popup needs a focus reset (click a neutral
control between opens).

```jsonc
{ "id": "open", "action": "press", "level": "happyPath",
  "target": { "identifier": "settings.appearancePopup" } },
{ "id": "pick", "action": "click", "level": "happyPath",
  "target": { "role": "AXMenuItem", "title": "Dark" } },
{ "id": "check", "action": "assert", "level": "happyPath",
  "target": { "identifier": "settings.appearancePopup" },
  "assert": { "property": "value", "op": "equals", "expected": "Dark" } }
```
**Validate:** medit's `settings.*Popup` flows drive correctly via this recipe, and
the focus-reset guidance resolves the "second open does nothing" (D2) behavior.

### 6. Unsupported-key exit code 4 (closes **Key P2 / NICE**)
`autopilot run` now exits **4** for an unsupported key chord — distinct from exit
**2** (invalid/malformed plan) — so a suite runner can triage "key not supported
yet" from "plan is broken."
**Validate:** in the suite runner, treat exit 4 differently if you special-case
unsupported keys. (Exit codes: 0 ok · 1 test-failed · 2 invalid plan · 3 no
Accessibility · 4 unsupported key.)

### 7. Re-editing the SAME field twice now takes (closes **D3**)
Your exact repro (`type` clear+commit `settings.tabWidth` = `6`, then again = `3`)
now ends at **3**. Before the fix the second `type` was silently dropped because
the prior Return tore down the field editor; `type` now confirms focus and re-arms
the field editor (AXPress) before typing. **No plan change needed.**
```jsonc
// two edits of the SAME field in one run — the second now commits:
{ "id": "e1", "action": "type", "level": "happyPath",
  "target": { "identifier": "settings.tabWidth" },
  "args": { "text": "6", "clear": true, "commit": true } },
{ "id": "c1", "action": "assert", "level": "happyPath",
  "target": { "identifier": "settings.tabWidth" },
  "assert": { "property": "value", "op": "equals", "expected": "6" } },
{ "id": "e2", "action": "type", "level": "tryToBreakIt",
  "target": { "identifier": "settings.tabWidth" },
  "args": { "text": "3", "clear": true, "commit": true } },
{ "id": "c2", "action": "assert", "level": "tryToBreakIt",
  "target": { "identifier": "settings.tabWidth" },
  "assert": { "property": "value", "op": "equals", "expected": "3" } }   // now PASSES
```
**Validate:** the plan above passes end to end. **Remove your D3 workarounds** —
you no longer need to edit each field at most once per plan or split re-edit cases
across plans. *(Verified directly against your medit Debug build: pre-fix `c2`
failed `expected=3 actual=6`; post-fix 6/6 PASS.)*

### 8. First `type` into a freshly-opened Settings panel (closes the new readiness flake)
The `waitFor <field> present`-then-first-`type`-lands-nothing flake (you saw ~3/5)
is fixed by the same change: `type` now polls focus/editability and retries before
sending keystrokes, so `waitFor present` no longer gives a false "ready."
**Validate:** your `settings-*` plans that open Settings via `cmd+,` and immediately
`type` — you should be able to **drop the short settle** after opening the panel.
*(Note: this readiness race is host-load-dependent and did not reproduce on my
machine; please confirm on yours and report if it still flakes. The confirm-loop is
the correct mitigation and is proven harmless — existing typing tests still pass.)*

### 9. Insert / overwrite-mode key (closes **overwrite-mode gap**)
`keyPress` now accepts `"insert"` (and its AppKit alias `"help"`), mapped to
`kVK_Help` (114) — so a plan can toggle medit's overwrite mode.
```jsonc
{ "id": "toggle-ovr", "action": "keyPress", "level": "integrationSuite",
  "target": { "identifier": "editorTextView" }, "args": { "keys": "insert" } }
```
**Validate:** `keyPress "insert"` toggles the OVR indicator (assert the
`modeLabel`/OVR-pill side effect — remember menu/label *state* isn't readable
directly, so assert the observable indicator).

### 10. `exec` step — file-change + Save-verification (closes the **reload-banner** + **Save disk-content** gaps)
A new `exec` step runs a shell command from within a plan. Provide **exactly one**
of `command` (a shell string via `/bin/sh -c`) or `argv` (a `[program, arg…]` array,
no shell). Bounded by `timeoutMs` (a hung command is killed → step fails).
- A **bare** `exec` (no `assert`) is a **setup/teardown lever** — it runs and
  **always passes**, ignoring the exit code.
- To **gate**, attach an `assert` on `stdout` / `stderr` / `exitCode`
  (`stdout`/`stderr` → `equals`/`contains`/`matches`; `exitCode` → those +
  `greaterThan`/`lessThan`; `stdout`/`stderr` are trimmed of one trailing newline).

```jsonc
// (a) trigger medit's reload banner — mutate the open file on disk mid-plan:
{ "id": "touch", "action": "exec", "level": "integrationSuite",
  "args": { "command": "echo 'changed on disk' > /tmp/medit-ap/doc.md" } },
// … then assert medit's reload/external-change banner appears.

// (b) verify a Save wrote the right bytes to disk:
{ "id": "verify-save", "action": "exec", "level": "happyPath",
  "args": { "argv": ["/bin/cat", "/tmp/medit-ap/doc.md"] },
  "assert": { "property": "stdout", "op": "contains", "expected": "the saved line" } }
```
**Validate:** (a) replace your out-of-band `osascript` file-mutation with an inline
`exec` and confirm the reload banner fires from within one plan; (b) after a Save,
`exec`-`cat` the file and assert its contents — no more paste-to-verify indirection.
Arbitrary cross-plan setup (kill app, restage fixtures) still belongs in the suite
runner; `exec` is for what a single plan needs inline. See AUTHORING **§5a**.

---

## Part 2 — Older report items that are ALREADY FIXED (re-validate + remove workarounds)

Much of medit's earlier report (Rounds 1–3) was fixed in intervening releases;
the report predates the fixes. Medit may still carry workarounds that can now be
**removed and re-validated**:

- **Suite-runner AX-linger race** (the most-repeated ask): `AppLauncher.launch`
  now waits for prior instances to leave the process table
  (`waitForExistingInstancesToExit`) and force-terminates stragglers before the
  next launch. → **Try removing the `pkill -9` + `sleep 1.5` between plans** and
  see if the suite is stable without it.
- Value/property asserts **poll** (no more scattered `wait` settles before an
  assert).
- **`focus:false`** for already-focused fields; full **punctuation** key map
  (`cmd+,`); **checkbox numeric AXValue** reads (`"0"`/`"1"`); `menu` + `press`
  actions; app-activation before input; `index`/`within` disambiguators; `count`
  assert; ambiguous-selector errors **list the matches**; `--pid` attach on
  `dump-axtree`/`find`/`suggest` (no phantom-window).
- Screenshots on **negative / secondary-display** origins (the ScreenCaptureKit
  rewrite handles multi-display).

Full fixed-vs-open ledger: **`docs/autopilot-feedback-response.md`**.

---

## Part 3 — What is genuinely NOT fixable

- **Exact screenshot hues / pixel-perfect visual state** are display/theme/GPU
  dependent. Use tolerance-based `assertPixel`/`assertRegion` or `snapshot` with a
  `maxDiff` (all already provided), or medit's own snapshot tests for dense checks.

---

## After validation

If the branch holds up against medit's suite, that's the green light to cut an
AutoPilot release (behind the explicit "go"): revert the local `-core` path
override in `autopilot-macos/Package.swift` to the released git dependency, tag
core + macos, bump the Homebrew tap, and `brew upgrade` so medit's black-box
install matches. Until then, medit validates from the branch build above.
