# TestHostApp UI Surface Specification

**Version:** 1.0  
**Applies to:** `autopilot-macos`, `autopilot-ios` (planned), `autopilot-android` (planned)

---

## Purpose

Every AutoPilot platform ships a `TestHostApp` — a minimal native app that exposes a fixed, well-known UI surface. A single canonical test plan (`Fixtures/TestHostApp/test-all-capabilities.json`) runs against all three apps unchanged. The runner for each platform translates each plan step into the platform's native mechanism; the plan itself contains no platform-specific knowledge.

This document is the authoritative contract between the test plan and every `TestHostApp` implementation. When you add a new platform, build a `TestHostApp` that satisfies every element in the **Element Surface** table and every **Implementation Notes** section below.

---

## Design Principles

1. **One plan, all platforms.** The JSON plan is the single source of truth. Runners translate; the plan does not branch.
2. **Minimize platform-only steps.** If an action genuinely has no cross-platform equivalent (e.g. `assertPixel` requires screen-capture permission that doesn't exist on Android), the step is skipped by the runner — not removed from the plan. The plan remains unified.
3. **Stable identifiers.** Every interactive element has a fixed `identifier` string. Identifiers are the primary selector in the test plan. Role/title selectors are secondary, used only when a platform's accessibility system doesn't support identifier lookup.
4. **Extend, don't break.** New elements and steps may be added to future versions of this spec. Existing identifiers and step IDs are never renamed or removed — only added to.

---

## Element Surface

Every `TestHostApp` implementation must expose the following elements with these exact identifiers, roles, and behaviors. The "Plan selector" column shows how the test plan targets each element.

| # | Identifier | Role (AX / iOS / Android) | Type | Behavior | Plan selector |
|---|---|---|---|---|---|
| 1 | `nameField` | `AXTextField` / `TextField` / `EditText` | Text input | Displays typed text; live-updates `statusLabel` on every keystroke | `{"identifier":"nameField"}` |
| 2 | `statusLabel` | `AXStaticText` / `Label` / `TextView` | Read-only label | Reflects: `"status: <nameField value>"`, `"status: flag=true/false"`, `"status: context-tapped"` | `{"identifier":"statusLabel"}` |
| 3 | `countLabel` | `AXStaticText` / `Label` / `TextView` | Read-only label | Shows `"count: N"` where N increments each time `okButton` is activated | `{"identifier":"countLabel"}` |
| 4 | `dblLabel` | `AXStaticText` / `Label` / `TextView` | Read-only label | Shows `"dbl: N"` where N increments each time `dblButton` receives a double-tap/double-click | `{"identifier":"dblLabel"}` |
| 5 | `okButton` | `AXButton` / `Button` / `Button` | Button | Single click/tap increments `countLabel` | `{"identifier":"okButton"}` |
| 6 | `dblButton` | `AXButton` / `Button` / `Button` | Double-click/tap target | Double-click or double-tap increments `dblLabel` | `{"identifier":"dblButton"}` |
| 7 | `flagCheckbox` | `AXCheckBox` / `Switch` / `CheckBox` | Toggle | Starts unchecked (value `"0"`/`"false"`); toggling changes value to `"1"`/`"true"` | `{"identifier":"flagCheckbox"}` |
| 8 | `colorSwatch` | `AXGroup` / `View` / `View` | Solid-color view | Filled with exactly `#3478F6` (sRGB 52, 120, 246). Used for `assertPixel`, `assertRegion`, `snapshot`, `screenshot` | `{"identifier":"colorSwatch"}` |
| 9 | `searchField` | `AXTextField` / `SearchField` / `SearchView` | Search input | Made first responder on launch; used to test keycode-based type and `focused` property | `{"identifier":"searchField"}` |
| 10 | `scrollView` | `AXScrollArea` / `ScrollView` / `ScrollView` | Scrollable container | Contains items `item-0` … `item-8` and `scroll-end`; `scroll-end` is off-screen initially | `{"identifier":"scrollView"}` |
| 11 | `scroll-end` | `AXStaticText` / `Label` / `TextView` | Label at bottom of scroll | Becomes visible after scrolling down; used to verify `scroll` action | `{"identifier":"scroll-end"}` |
| 12 | `slider` | `AXSlider` / `Slider` / `SeekBar` | Continuous slider | Range 0–100, starts at 0; drag/swipe right increases value | `{"identifier":"slider"}` |
| 13 | `sliderValueLabel` | `AXStaticText` / `Label` / `TextView` | Read-only label | Shows `"slider: N"` where N is the current integer slider value | `{"identifier":"sliderValueLabel"}` |
| 14 | `rightClickTarget` | `AXGroup` / `View` / `View` | Context-menu trigger | Right-click (macOS), long-press (iOS/Android) reveals a context menu with item `"ContextAction"` | `{"identifier":"rightClickTarget"}` |
| 15 | `ContextAction` | `AXMenuItem` / `Button` / `MenuItem` | Context menu item | Selecting it sets `statusLabel` to `"status: context-tapped"` | `{"role":"AXMenuItem","title":"ContextAction"}` (macOS) / `{"identifier":"contextAction"}` (iOS/Android) |
| 16 | `Toggle Flag` | `AXMenuItem` / — / — | Menu bar item (macOS) / nav action (iOS) / overflow item (Android) | Toggles `flagOn`; checkmark visible when on; maps to `menu` action | `{"role":"AXMenuItem","title":"Toggle Flag"}` |
| 17 | `modeSegment` | `AXRadioGroup` / `SegmentedControl` / `RadioGroup` | Segmented control | 3 segments: Alpha (0), Beta (1), Gamma (2); selection updates `segmentLabel` to `"segment: N"` | `{"role":"AXRadioButton","index":N,"within":{"identifier":"modeSegment"}}` |
| 18 | `segmentLabel` | `AXStaticText` / `Label` / `TextView` | Read-only label | Shows `"segment: N"` where N is the index of the selected segment | `{"identifier":"segmentLabel"}` |
| 19 | `colorPicker` | `AXPopUpButton` / `Picker` / `Spinner` | Dropdown / popup button | 3 options: Red, Green, Blue; selection updates `pickerLabel` to `"pick: <title>"` | `{"identifier":"colorPicker"}` (open) then `{"role":"AXMenuItem","title":"<option>"}` (select) |
| 20 | `pickerLabel` | `AXStaticText` / `Label` / `TextView` | Read-only label | Shows `"pick: <color>"` mirroring the active picker selection | `{"identifier":"pickerLabel"}` |
| 21 | `quantityStepper` | `AXIncrementor` / `Stepper` / — | Stepper | Range 0–10, step 1; first AXButton child (index 0) increments, second (index 1) decrements; updates `quantityLabel` | `{"role":"AXButton","index":0,"within":{"identifier":"quantityStepper"}}` |
| 22 | `quantityLabel` | `AXStaticText` / `Label` / `TextView` | Read-only label | Shows `"qty: N"` where N is the current stepper value | `{"identifier":"quantityLabel"}` |
| 23 | `uploadProgress` | `AXValueIndicator` / `ProgressView` / `ProgressBar` | Progress indicator | Range 0.0–1.0, starts at 0.5; `advanceButton` sets it to 1.0 | `{"identifier":"uploadProgress"}` |
| 24 | `advanceButton` | `AXButton` / `Button` / `Button` | Button | Sets `uploadProgress` to 1.0 (full) | `{"identifier":"advanceButton"}` |
| 25 | `notesArea` | `AXTextArea` / `TextEditor` / `EditText` | Multi-line text area | Editable; accepts multi-line text (newlines via Return key or `\n`); `setValue` writes the full value | `{"identifier":"notesArea"}` |
| 26 | `termsLink` | `AXLink` / `Link` / `TextView` | Tappable link | Clicking/tapping sets `statusLabel` to `"status: link-tapped"` | `{"identifier":"termsLink"}` |
| 27 | `fileTable` | `AXTable` / `TableView` / `RecyclerView` | Table / list | 3 rows: document.pdf, photo.jpg, notes.txt; row cells have identifiers `row-<filename>`; selection updates `tableSelLabel` | `{"identifier":"fileTable"}` |
| 28 | `row-document.pdf` | `AXStaticText` / cell / item | Table row cell | Clicking/tapping selects the row and sets `tableSelLabel` to `"table-sel: document.pdf"` | `{"identifier":"row-document.pdf"}` |
| 29 | `row-photo.jpg` | `AXStaticText` / cell / item | Table row cell | Clicking/tapping selects the row and sets `tableSelLabel` to `"table-sel: photo.jpg"` | `{"identifier":"row-photo.jpg"}` |
| 30 | `row-notes.txt` | `AXStaticText` / cell / item | Table row cell | Clicking/tapping selects the row and sets `tableSelLabel` to `"table-sel: notes.txt"` | `{"identifier":"row-notes.txt"}` |
| 31 | `tableSelLabel` | `AXStaticText` / `Label` / `TextView` | Read-only label | Shows `"table-sel: <filename>"` or `"table-sel: none"` when no row selected | `{"identifier":"tableSelLabel"}` |
| 32 | `alertButton` | `AXButton` / `Button` / `Button` | Alert trigger | Shows a modal alert/dialog titled `"Are you sure?"` with Confirm and Cancel buttons | `{"identifier":"alertButton"}` |
| 33 | `confirmButton` | `AXButton` / `Button` / `Button` | Alert confirm | Inside the modal; pressing sets `statusLabel` to `"status: alert-confirmed"` and dismisses | `{"identifier":"confirmButton"}` |
| 34 | `cancelButton` | `AXButton` / `Button` / `Button` | Alert cancel | Inside the modal; pressing sets `statusLabel` to `"status: alert-cancelled"` and dismisses | `{"identifier":"cancelButton"}` |
| 35 | `lockedButton` | `AXButton` / `Button` / `Button` | Disabled button | `isEnabled = false`; exists in AX tree but cannot be activated; `enabled` property reads `"false"` | `{"identifier":"lockedButton"}` |
| 36 | `disabledLabel` | `AXStaticText` / `Label` / `TextView` | Read-only label | Shows `"locked: true"` (static) | `{"identifier":"disabledLabel"}` |

> **Note on `Toggle Flag` / menu action:** On macOS this lives in the `View` menu bar. On iOS it maps to a navigation bar button or action sheet. On Android it maps to an options menu item. The plan uses `"action":"menu"` with `"menuPath":["View","Toggle Flag"]`; each runner translates the path to its platform's menu navigation mechanism.

> **Note on segmented control (E1):** macOS exposes `NSSegmentedControl` as `AXRadioGroup` with `AXRadioButton` children that have no `title` in the AX tree — target by `index` (0-based). On iOS use `UISegmentedControl` with `accessibilityIdentifier` on the control itself and select by value. On Android use `RadioGroup` or `TabLayout`.

> **Note on picker (E2):** `press` opens the popup; a second `press` on `{"role":"AXMenuItem","title":"..."}` selects an item. `setValue` writes the AX value directly but fires no target-action handler, so use press+press if the label must update.

> **Note on stepper (E3):** macOS `AXIncrementor` child buttons have no stable titles (localization-dependent). Use `index` (0 = increment top button, 1 = decrement bottom button). On iOS use `UIStepper` value change. On Android use `+`/`-` buttons with identifiers.

> **Note on alert/sheet (E8):** macOS shows an `NSAlert` as an `AXSheet`; use `waitFor role=AXSheet present:true` to detect it, then press the button by identifier, then `waitFor present:false` to confirm dismissal. On iOS use `UIAlertController`; on Android use `AlertDialog`.

> **Note on disabled element (E9):** The element must appear in the accessibility tree with `enabled=false`. Plans assert `enabled` / `equals` / `"false"`. Runners must NOT attempt to activate the element.

---

## Unified Test Plan

`Fixtures/TestHostApp/test-all-capabilities.json`

This plan exercises every AutoPilot capability in sequence. The `target` field is intentionally left with a placeholder bundle ID — each platform's test harness substitutes the correct value (or the runner resolves it by path). Steps are ordered to build on each other; the app is launched once and terminated at the end.

```json
{
  "schemaVersion": "1.0",
  "name": "testhostapp-all-capabilities",
  "target": { "bundleId": "com.autopilot.testhostapp" },
  "defaults": { "timeoutMs": 5000, "retryIntervalMs": 100 },
  "steps": [

    { "id": "wait-window",
      "action": "waitFor",
      "target": { "role": "AXWindow" },
      "args": { "present": true } },

    { "id": "type-name",
      "action": "type",
      "target": { "identifier": "nameField" },
      "args": { "text": "Ada", "clear": true } },

    { "id": "assert-status-name",
      "action": "assert",
      "target": { "identifier": "statusLabel" },
      "assert": { "property": "value", "op": "contains", "expected": "Ada" } },

    { "id": "set-value",
      "action": "setValue",
      "target": { "identifier": "nameField" },
      "args": { "text": "Zed-42" } },

    { "id": "assert-set-value",
      "action": "assert",
      "target": { "identifier": "nameField" },
      "assert": { "property": "value", "op": "matches", "expected": "Zed-\d+" } },

    { "id": "click-ok",
      "action": "click",
      "target": { "identifier": "okButton" } },

    { "id": "assert-count-1",
      "action": "assert",
      "target": { "identifier": "countLabel" },
      "assert": { "property": "value", "op": "equals", "expected": "count: 1" } },

    { "id": "assert-ok-title",
      "action": "assert",
      "target": { "identifier": "okButton" },
      "assert": { "property": "title", "op": "equals", "expected": "OK" } },

    { "id": "assert-ok-enabled",
      "action": "assert",
      "target": { "identifier": "okButton" },
      "assert": { "property": "enabled", "op": "equals", "expected": "true" } },

    { "id": "press-ok",
      "action": "press",
      "target": { "identifier": "okButton" } },

    { "id": "assert-count-2",
      "action": "assert",
      "target": { "identifier": "countLabel" },
      "assert": { "property": "value", "op": "equals", "expected": "count: 2" } },

    { "id": "double-click",
      "action": "doubleClick",
      "target": { "identifier": "dblButton" } },

    { "id": "assert-dbl-1",
      "action": "assert",
      "target": { "identifier": "dblLabel" },
      "assert": { "property": "value", "op": "equals", "expected": "dbl: 1" } },

    { "id": "check-flag",
      "action": "press",
      "target": { "identifier": "flagCheckbox" } },

    { "id": "assert-checked",
      "action": "assert",
      "target": { "identifier": "flagCheckbox" },
      "assert": { "property": "value", "op": "equals", "expected": "1" } },

    { "id": "assert-search-focused",
      "action": "assert",
      "target": { "identifier": "searchField" },
      "assert": { "property": "focused", "op": "equals", "expected": "true" } },

    { "id": "type-search",
      "action": "type",
      "target": { "identifier": "searchField" },
      "args": { "text": "Query 9", "focus": false } },

    { "id": "assert-search-value",
      "action": "assert",
      "target": { "identifier": "searchField" },
      "assert": { "property": "value", "op": "equals", "expected": "Query 9" } },

    { "id": "keypress-select-all",
      "action": "keyPress",
      "target": { "identifier": "nameField" },
      "args": { "keys": "cmd+a" } },

    { "id": "scroll-down",
      "action": "scroll",
      "target": { "identifier": "scrollView" },
      "args": { "deltaY": -300 } },

    { "id": "assert-scroll-end-visible",
      "action": "waitFor",
      "target": { "identifier": "scroll-end" },
      "args": { "present": true } },

    { "id": "assert-slider-zero",
      "action": "assert",
      "target": { "identifier": "sliderValueLabel" },
      "assert": { "property": "value", "op": "equals", "expected": "slider: 0" } },

    { "id": "drag-slider",
      "action": "drag",
      "target": { "identifier": "slider" },
      "args": { "to": { "identifier": "sliderValueLabel" } } },

    { "id": "assert-slider-moved",
      "action": "assert",
      "target": { "identifier": "sliderValueLabel" },
      "assert": { "property": "value", "op": "notEquals", "expected": "slider: 0" } },

    { "id": "right-click-target",
      "action": "rightClick",
      "target": { "identifier": "rightClickTarget" } },

    { "id": "press-context-item",
      "action": "press",
      "target": { "role": "AXMenuItem", "title": "ContextAction" } },

    { "id": "assert-context-tapped",
      "action": "assert",
      "target": { "identifier": "statusLabel" },
      "assert": { "property": "value", "op": "contains", "expected": "context-tapped" } },

    { "id": "menu-toggle-flag",
      "action": "menu",
      "args": { "menuPath": ["View", "Toggle Flag"] } },

    { "id": "assert-flag-status",
      "action": "assert",
      "target": { "identifier": "statusLabel" },
      "assert": { "property": "value", "op": "contains", "expected": "flag=true" } },

    { "id": "assert-menu-marked",
      "action": "assert",
      "target": { "role": "AXMenuItem", "title": "Toggle Flag" },
      "assert": { "property": "marked", "op": "equals", "expected": "true" } },

    { "id": "assert-count-gt-1",
      "action": "assert",
      "target": { "role": "AXButton" },
      "assert": { "property": "count", "op": "greaterThan", "expected": "1" } },

    { "id": "assert-colorSwatch-position",
      "action": "assert",
      "target": { "identifier": "colorSwatch" },
      "assert": { "property": "position", "op": "contains", "expected": "," } },

    { "id": "assert-colorSwatch-size",
      "action": "assert",
      "target": { "identifier": "colorSwatch" },
      "assert": { "property": "size", "op": "contains", "expected": "," } },

    { "id": "assert-pixel",
      "action": "assertPixel",
      "target": { "identifier": "colorSwatch" },
      "args": { "color": "#3478F6", "tolerance": 16 } },

    { "id": "assert-region",
      "action": "assertRegion",
      "target": { "identifier": "colorSwatch" },
      "args": { "color": "#3478F6", "width": 12, "height": 12, "mode": "dominant", "tolerance": 16 } },

    { "id": "snapshot-swatch",
      "action": "snapshot",
      "target": { "identifier": "colorSwatch" },
      "args": { "reference": "ref/swatch.png", "width": 30, "height": 30 } },

    { "id": "screenshot-swatch",
      "action": "screenshot",
      "target": { "identifier": "colorSwatch" },
      "args": { "padding": 4 } },

    { "id": "explicit-wait",
      "action": "wait",
      "args": { "seconds": 0.05 } },

    { "id": "assert-not-equals",
      "action": "assert",
      "target": { "identifier": "nameField" },
      "assert": { "property": "value", "op": "notEquals", "expected": "Ada" } },

    { "id": "assert-exists",
      "action": "assert",
      "target": { "identifier": "okButton" },
      "assert": { "property": "value", "op": "exists" } },

    { "id": "assert-not-exists",
      "action": "assert",
      "target": { "identifier": "okButton", "within": { "role": "AXMenuBar" } },
      "assert": { "property": "value", "op": "notExists" } },

    { "comment": "── E1: Segmented control ──────────────────────────────────────────────────",
      "id": "segment-press-beta",
      "action": "press",
      "target": { "role": "AXRadioButton", "index": 1, "within": { "identifier": "modeSegment" } } },

    { "id": "segment-assert-1",
      "action": "assert",
      "target": { "identifier": "segmentLabel" },
      "assert": { "property": "value", "op": "equals", "expected": "segment: 1" } },

    { "id": "segment-press-gamma",
      "action": "press",
      "target": { "role": "AXRadioButton", "index": 2, "within": { "identifier": "modeSegment" } } },

    { "id": "segment-assert-2",
      "action": "assert",
      "target": { "identifier": "segmentLabel" },
      "assert": { "property": "value", "op": "equals", "expected": "segment: 2" } },

    { "comment": "── E2: Picker / dropdown (NSPopUpButton) ──────────────────────────────────",
      "id": "picker-open",
      "action": "press",
      "target": { "identifier": "colorPicker" } },

    { "id": "picker-select-blue",
      "action": "press",
      "target": { "role": "AXMenuItem", "title": "Blue" } },

    { "id": "picker-assert-label",
      "action": "assert",
      "target": { "identifier": "pickerLabel" },
      "assert": { "property": "value", "op": "equals", "expected": "pick: Blue" } },

    { "comment": "── E3: Stepper ────────────────────────────────────────────────────────────",
      "id": "stepper-assert-zero",
      "action": "assert",
      "target": { "identifier": "quantityLabel" },
      "assert": { "property": "value", "op": "equals", "expected": "qty: 0" } },

    { "id": "stepper-increment",
      "action": "press",
      "target": { "role": "AXButton", "index": 0, "within": { "identifier": "quantityStepper" } } },

    { "id": "stepper-assert-one",
      "action": "assert",
      "target": { "identifier": "quantityLabel" },
      "assert": { "property": "value", "op": "equals", "expected": "qty: 1" } },

    { "id": "stepper-decrement",
      "action": "press",
      "target": { "role": "AXButton", "index": 1, "within": { "identifier": "quantityStepper" } } },

    { "id": "stepper-assert-zero-again",
      "action": "assert",
      "target": { "identifier": "quantityLabel" },
      "assert": { "property": "value", "op": "equals", "expected": "qty: 0" } },

    { "comment": "── E4: Progress indicator ──────────────────────────────────────────────────",
      "id": "progress-assert-half",
      "action": "assert",
      "target": { "identifier": "uploadProgress" },
      "assert": { "property": "value", "op": "equals", "expected": "0.5" } },

    { "id": "progress-assert-gt-zero",
      "action": "assert",
      "target": { "identifier": "uploadProgress" },
      "assert": { "property": "value", "op": "greaterThan", "expected": "0.0" } },

    { "id": "progress-assert-lt-one",
      "action": "assert",
      "target": { "identifier": "uploadProgress" },
      "assert": { "property": "value", "op": "lessThan", "expected": "1.0" } },

    { "id": "progress-advance",
      "action": "click",
      "target": { "identifier": "advanceButton" } },

    { "id": "progress-assert-complete",
      "action": "assert",
      "target": { "identifier": "uploadProgress" },
      "assert": { "property": "value", "op": "equals", "expected": "1.0" } },

    { "comment": "── E5: Multi-line text area ────────────────────────────────────────────────",
      "id": "notes-type",
      "action": "type",
      "target": { "identifier": "notesArea" },
      "args": { "text": "Line one
Line two
Line three" } },

    { "id": "notes-assert-contains",
      "action": "assert",
      "target": { "identifier": "notesArea" },
      "assert": { "property": "value", "op": "contains", "expected": "Line two" } },

    { "id": "notes-set-value",
      "action": "setValue",
      "target": { "identifier": "notesArea" },
      "args": { "text": "Replaced" } },

    { "id": "notes-assert-replaced",
      "action": "assert",
      "target": { "identifier": "notesArea" },
      "assert": { "property": "value", "op": "equals", "expected": "Replaced" } },

    { "comment": "── E6: Link / tappable label ───────────────────────────────────────────────",
      "id": "link-assert-exists",
      "action": "assert",
      "target": { "identifier": "termsLink" },
      "assert": { "property": "value", "op": "exists" } },

    { "id": "link-click",
      "action": "click",
      "target": { "identifier": "termsLink" } },

    { "id": "link-assert-status",
      "action": "assert",
      "target": { "identifier": "statusLabel" },
      "assert": { "property": "value", "op": "contains", "expected": "link-tapped" } },

    { "comment": "── E7: Table / list rows ───────────────────────────────────────────────────",
      "id": "table-count-rows",
      "action": "assert",
      "target": { "role": "AXStaticText", "within": { "identifier": "fileTable" } },
      "assert": { "property": "count", "op": "equals", "expected": "3" } },

    { "id": "table-click-first-row",
      "action": "click",
      "target": { "identifier": "row-document.pdf" } },

    { "id": "table-assert-sel-first",
      "action": "assert",
      "target": { "identifier": "tableSelLabel" },
      "assert": { "property": "value", "op": "equals", "expected": "table-sel: document.pdf" } },

    { "id": "table-row-exists",
      "action": "assert",
      "target": { "identifier": "row-photo.jpg" },
      "assert": { "property": "value", "op": "exists" } },

    { "comment": "── E8: Alert / modal sheet ─────────────────────────────────────────────────",
      "id": "alert-trigger",
      "action": "click",
      "target": { "identifier": "alertButton" } },

    { "id": "alert-wait-sheet",
      "action": "waitFor",
      "target": { "role": "AXSheet" },
      "args": { "present": true } },

    { "id": "alert-confirm",
      "action": "press",
      "target": { "identifier": "confirmButton" } },

    { "id": "alert-wait-dismissed",
      "action": "waitFor",
      "target": { "role": "AXSheet" },
      "args": { "present": false } },

    { "id": "alert-assert-confirmed",
      "action": "assert",
      "target": { "identifier": "statusLabel" },
      "assert": { "property": "value", "op": "contains", "expected": "alert-confirmed" } },

    { "comment": "── E9: Disabled element ────────────────────────────────────────────────────",
      "id": "disabled-assert-exists",
      "action": "assert",
      "target": { "identifier": "lockedButton" },
      "assert": { "property": "value", "op": "exists" } },

    { "id": "disabled-assert-enabled-false",
      "action": "assert",
      "target": { "identifier": "lockedButton" },
      "assert": { "property": "enabled", "op": "equals", "expected": "false" } },

    { "id": "disabled-assert-label",
      "action": "assert",
      "target": { "identifier": "disabledLabel" },
      "assert": { "property": "value", "op": "equals", "expected": "locked: true" } },

    { "id": "terminate",
      "action": "terminate" }
  ]
}
```

---

## Capability Coverage Map

| Step ID | Action | Assert property / op | Capability exercised |
|---|---|---|---|
| `wait-window` | `waitFor` | — | Element presence wait |
| `type-name` | `type` | — | Text input with `clear` |
| `assert-status-name` | `assert` | `value` / `contains` | Live label update; `contains` op |
| `set-value` | `setValue` | — | Direct AX/a11y value write |
| `assert-set-value` | `assert` | `value` / `matches` | Regex match op |
| `click-ok` | `click` | — | Coordinate click |
| `assert-count-1` | `assert` | `value` / `equals` | Exact value match |
| `assert-ok-title` | `assert` | `title` / `equals` | Title property |
| `assert-ok-enabled` | `assert` | `enabled` / `equals` | Enabled property |
| `press-ok` | `press` | — | AX press action |
| `assert-count-2` | `assert` | `value` / `equals` | Cumulative state |
| `double-click` | `doubleClick` | — | Double-click / double-tap |
| `assert-dbl-1` | `assert` | `value` / `equals` | Double-click result |
| `check-flag` | `press` | — | Toggle via press |
| `assert-checked` | `assert` | `value` / `equals` | Checkbox numeric value |
| `assert-search-focused` | `assert` | `focused` / `equals` | Focused property |
| `type-search` | `type` | — | Type with `focus: false` (keycode path) |
| `assert-search-value` | `assert` | `value` / `equals` | Search field value |
| `keypress-select-all` | `keyPress` | — | Chord key synthesis |
| `scroll-down` | `scroll` | — | Scroll action |
| `assert-scroll-end-visible` | `waitFor` | — | Post-scroll presence |
| `assert-slider-zero` | `assert` | `value` / `equals` | Initial slider state |
| `drag-slider` | `drag` | — | Drag gesture |
| `assert-slider-moved` | `assert` | `value` / `notEquals` | Drag result; `notEquals` op |
| `right-click-target` | `rightClick` | — | Right-click / long-press |
| `press-context-item` | `press` | — | Context menu item press |
| `assert-context-tapped` | `assert` | `value` / `contains` | Context action result |
| `menu-toggle-flag` | `menu` | — | Menu bar / nav menu navigation |
| `assert-flag-status` | `assert` | `value` / `contains` | Menu action result |
| `assert-menu-marked` | `assert` | `marked` / `equals` | Menu item checkmark |
| `assert-count-gt-1` | `assert` | `count` / `greaterThan` | Multi-element count |
| `assert-colorSwatch-position` | `assert` | `position` / `contains` | Position property |
| `assert-colorSwatch-size` | `assert` | `size` / `contains` | Size property |
| `assert-pixel` | `assertPixel` | — | Pixel color sampling |
| `assert-region` | `assertRegion` | — | Region color (dominant mode) |
| `snapshot-swatch` | `snapshot` | — | Visual regression reference |
| `screenshot-swatch` | `screenshot` | — | Element screenshot capture |
| `explicit-wait` | `wait` | — | Fixed delay |
| `assert-not-equals` | `assert` | `value` / `notEquals` | Negative value match |
| `assert-exists` | `assert` | `value` / `exists` | Existence check |
| `assert-not-exists` | `assert` | `value` / `notExists` | Scoped non-existence |
| `segment-press-beta` | `press` | — | Segmented control selection by child index |
| `segment-assert-1` | `assert` | `value` / `equals` | Segment label update |
| `segment-press-gamma` | `press` | — | Segmented control second selection |
| `segment-assert-2` | `assert` | `value` / `equals` | Segment label update (index 2) |
| `picker-open` | `press` | — | Popup button open |
| `picker-select-blue` | `press` | — | Popup menu item selection by title |
| `picker-assert-label` | `assert` | `value` / `equals` | Picker label update |
| `stepper-assert-zero` | `assert` | `value` / `equals` | Stepper initial label value |
| `stepper-increment` | `press` | — | Stepper increment via child button index |
| `stepper-assert-one` | `assert` | `value` / `equals` | Stepper label after increment |
| `stepper-decrement` | `press` | — | Stepper decrement via child button index |
| `stepper-assert-zero-again` | `assert` | `value` / `equals` | Stepper label after decrement |
| `progress-assert-half` | `assert` | `value` / `equals` | Progress indicator float value |
| `progress-assert-gt-zero` | `assert` | `value` / `greaterThan` | `greaterThan` op on numeric value |
| `progress-assert-lt-one` | `assert` | `value` / `lessThan` | `lessThan` op on numeric value |
| `progress-advance` | `click` | — | Button that mutates progress state |
| `progress-assert-complete` | `assert` | `value` / `equals` | Progress at 1.0 |
| `notes-type` | `type` | — | Multi-line text area; `\n` becomes Return |
| `notes-assert-contains` | `assert` | `value` / `contains` | Partial match on multi-line value |
| `notes-set-value` | `setValue` | — | Direct AX value write to clear+replace text area |
| `notes-assert-replaced` | `assert` | `value` / `equals` | Replaced text area content |
| `link-assert-exists` | `assert` | `value` / `exists` | Non-button AX role existence |
| `link-click` | `click` | — | Click on `AXLink` role |
| `link-assert-status` | `assert` | `value` / `contains` | Link tap side-effect |
| `table-count-rows` | `assert` | `count` / `equals` | Scoped element count inside table |
| `table-click-first-row` | `click` | — | Table row click by cell identifier |
| `table-assert-sel-first` | `assert` | `value` / `equals` | Selection label update |
| `table-row-exists` | `assert` | `value` / `exists` | Non-selected row existence |
| `alert-trigger` | `click` | — | Button that presents modal sheet |
| `alert-wait-sheet` | `waitFor` | — | Wait for `AXSheet` to appear |
| `alert-confirm` | `press` | — | Modal confirm button by identifier |
| `alert-wait-dismissed` | `waitFor` | — | Wait for `AXSheet` to disappear |
| `alert-assert-confirmed` | `assert` | `value` / `contains` | Post-dismiss status label |
| `disabled-assert-exists` | `assert` | `value` / `exists` | Disabled element is in AX tree |
| `disabled-assert-enabled-false` | `assert` | `enabled` / `equals` | Enabled property reads `"false"` |
| `disabled-assert-label` | `assert` | `value` / `equals` | Static label beside disabled element |
| `terminate` | `terminate` | — | App termination |

---

## Implementation Notes per Element

For each element, the notes show what you need to wire up in a new platform's `TestHostApp`. Code snippets are minimal — just enough to satisfy the test plan's expectations.

---

### 1. `nameField` — Text input

**Plan exercises:** `type`, `setValue`, `assert value`, `assert notEquals`, `keyPress` (target for select-all)

**What it must do:**
- Accept text input
- On every keystroke update `statusLabel` to `"status: <current text>"`

**macOS (AppKit)**
```swift
let nameField = NSTextField(frame: ...)
nameField.setAccessibilityIdentifier("nameField")
nameField.delegate = self          // controlTextDidChange fires on every keystroke
// In delegate:
func controlTextDidChange(_ obj: Notification) {
    statusLabel.stringValue = "status: \(nameField.stringValue)"
}
```

**iOS (UIKit)**
```swift
let nameField = UITextField()
nameField.accessibilityIdentifier = "nameField"
nameField.addTarget(self, action: #selector(nameChanged), for: .editingChanged)
@objc func nameChanged() {
    statusLabel.text = "status: \(nameField.text ?? "")"
}
```

**Android (XML + Kotlin)**
```xml
<EditText android:id="@+id/nameField"
          android:contentDescription="nameField" />
```
```kotlin
nameField.addTextChangedListener { statusLabel.text = "status: ${it}" }
```

---

### 2. `statusLabel` — Status display

**Plan exercises:** `assert value contains`, `assert value notEquals`

**What it must do:**
- Start as `"status: "` (empty)
- Be updated by: `nameField` keystrokes, `flagCheckbox` toggle (via menu), context menu selection

**macOS:** `NSTextField(labelWithString: "status: ")` with `setAccessibilityIdentifier("statusLabel")`  
**iOS:** `UILabel()` with `accessibilityIdentifier = "statusLabel"`  
**Android:** `<TextView android:contentDescription="statusLabel" />`

---

### 3. `countLabel` — Click counter display

**Plan exercises:** `assert value equals` (verifies `click` and `press` both fired)

**What it must do:**
- Start as `"count: 0"`
- Increment to `"count: 1"` after first `okButton` click, `"count: 2"` after `press`

**macOS:**
```swift
var count = 0
@objc func okTapped() { count += 1; countLabel.stringValue = "count: \(count)" }
```
**iOS:**
```swift
@objc func okTapped() { count += 1; countLabel.text = "count: \(count)" }
```
**Android:**
```kotlin
okButton.setOnClickListener { countLabel.text = "count: ${++count}" }
```

---

### 4. `dblLabel` — Double-click/tap counter

**Plan exercises:** `doubleClick`

**What it must do:**
- Start as `"dbl: 0"`
- Increment to `"dbl: 1"` on the first double-click or double-tap of `dblButton`

**macOS:** Custom `NSView` subclass; detect `event.clickCount == 2` in `mouseDown`.  
**iOS:** `UITapGestureRecognizer` with `numberOfTapsRequired = 2`.  
```swift
let dbl = UITapGestureRecognizer(target: self, action: #selector(doubleTapped))
dbl.numberOfTapsRequired = 2
dblButton.addGestureRecognizer(dbl)
@objc func doubleTapped() { dblCount += 1; dblLabel.text = "dbl: \(dblCount)" }
```
**Android:** `GestureDetector.OnDoubleTapListener`.
```kotlin
val detector = GestureDetector(context, object : GestureDetector.SimpleOnGestureListener() {
    override fun onDoubleTap(e: MotionEvent): Boolean {
        dblLabel.text = "dbl: ${++dblCount}"; return true
    }
})
dblButton.setOnTouchListener { _, e -> detector.onTouchEvent(e); true }
```

---

### 5. `okButton` — Primary button

**Plan exercises:** `click`, `press`, `assert title`, `assert enabled`, `assert exists`, `assert count > 1`

**What it must do:**
- Title/label exactly `"OK"`
- Enabled at all times
- Single click or press increments `countLabel`

**macOS:** `NSButton(title: "OK", ...)` with `setAccessibilityIdentifier("okButton")`  
**iOS:** `UIButton`; `setTitle("OK", for: .normal)`; `accessibilityIdentifier = "okButton"`  
**Android:** `<Button android:text="OK" android:contentDescription="okButton" />`

---

### 6. `dblButton` — Double-click/tap target

**Plan exercises:** `doubleClick`

**What it must do:**
- Exposed as a button in the accessibility tree (so the runner can resolve it by identifier)
- Respond to double-click/double-tap by incrementing `dblLabel`
- Single click does nothing (prevents accidental counter increment from the first half of a double-click)

**macOS:**
```swift
// NSView subclass; must call setAccessibilityElement(true) or it won't appear in AX tree
dblButton.setAccessibilityElement(true)
dblButton.setAccessibilityRole(.button)
dblButton.setAccessibilityIdentifier("dblButton")
```
**iOS:** Any `UIView`; set `isAccessibilityElement = true`, `accessibilityTraits = .button`, `accessibilityIdentifier = "dblButton"`.  
**Android:** `<View android:contentDescription="dblButton" android:focusable="true" />`

---

### 7. `flagCheckbox` — Toggle / checkbox

**Plan exercises:** `press` (toggle), `assert value equals "0"` / `"1"`

**What it must do:**
- Start unchecked; AX value `"0"` when off, `"1"` when on
- Toggled by `press` action (AX press, not coordinate click)

**macOS:** `NSButton(checkboxWithTitle: "Flag", ...)` — AX value is `NSNumber` `0`/`1`.  
**iOS:** `UISwitch`; `accessibilityValue` returns `"0"`/`"1"` based on `isOn`. Override if needed:
```swift
override var accessibilityValue: String? {
    get { isOn ? "1" : "0" }
    set { }
}
```
**Android:** `<CheckBox>`; `contentDescription = "flagCheckbox"`; override `getAccessibilityNodeInfo` or use `ViewCompat.setAccessibilityDelegate` to expose `"0"`/`"1"` as state text.

---

### 8. `colorSwatch` — Solid-color reference view

**Plan exercises:** `assertPixel`, `assertRegion`, `snapshot`, `screenshot`, `assert position`, `assert size`

**What it must do:**
- Fill solidly with `#3478F6` (sRGB: R=52, G=120, B=246)
- Be at least 60×60 pts/dp so region sampling and snapshot have sufficient area
- Exposed as an accessibility element with a position and size the runner can read

**macOS:**
```swift
swatch.wantsLayer = true
swatch.layer?.backgroundColor = NSColor(srgbRed: 52/255, green: 120/255,
                                         blue: 246/255, alpha: 1).cgColor
swatch.setAccessibilityElement(true)
swatch.setAccessibilityRole(.group)
swatch.setAccessibilityIdentifier("colorSwatch")
```
**iOS:**
```swift
swatch.backgroundColor = UIColor(red: 52/255, green: 120/255, blue: 246/255, alpha: 1)
swatch.isAccessibilityElement = true
swatch.accessibilityIdentifier = "colorSwatch"
```
**Android:**
```xml
<View android:id="@+id/colorSwatch"
      android:contentDescription="colorSwatch"
      android:background="#3478F6"
      android:minWidth="60dp" android:minHeight="60dp" />
```

> **Color precision:** The value `#3478F6` is the sRGB target. Wide-gamut displays may render it slightly outside the standard gamut; the test plan uses `tolerance: 16` to accommodate display-pipeline rounding.

---

### 9. `searchField` — Search / focused input

**Plan exercises:** `type` with `focus: false`, `assert focused`

**What it must do:**
- Be made first responder immediately on launch (before any user interaction)
- Accept text input via the keycode/virtual-key path (not unicode string injection)
- Report `focused = true` while it holds first responder

**macOS:** `NSSearchField`; `window.makeFirstResponder(search)` in a `DispatchQueue.main.async` block so it runs after the window is visible.  
**iOS:** Call `searchField.becomeFirstResponder()` in `viewDidAppear`.  
**Android:** `requestFocus()` in `onResume`; or set `android:focusableInTouchMode="true"` and `requestFocus()` in layout.

---

### 10–11. `scrollView` + `scroll-end` — Scrollable content

**Plan exercises:** `scroll`, `waitFor` post-scroll

**What it must do:**
- `scrollView`: a clipping scroll container; vertically scrollable
- Contains at least 10 items (`item-0` … `item-8`, `scroll-end`)
- `scroll-end` must be **off-screen** in the initial viewport
- After `"deltaY": -300` (scroll down), `scroll-end` must become visible in the accessibility tree

**macOS:** `NSScrollView` with a tall `documentView` (height > 3× clip height); `scroll-end` label at the bottom.  
**iOS:**
```swift
// UIScrollView with contentSize.height > frame.height * 3
// Place scroll-end label at bottom; set accessibilityIdentifier = "scroll-end"
scrollEnd.accessibilityIdentifier = "scroll-end"
```
**Android:**
```xml
<ScrollView android:id="@+id/scrollView"
            android:contentDescription="scrollView">
  <!-- 10 TextViews; last one: -->
  <TextView android:contentDescription="scroll-end" android:text="scroll-end" />
</ScrollView>
```

> **Runner note on `deltaY`:** On macOS `deltaY = -300` scroll-wheel units scrolls down. iOS/Android runners translate this to a swipe-up gesture or programmatic scroll offset proportional to `deltaY`. The exact pixel mapping is runner-defined; the contract is that `scroll-end` becomes visible.

---

### 12–13. `slider` + `sliderValueLabel` — Drag target

**Plan exercises:** `drag`, `assert value notEquals`, `assert value equals "slider: 0"` (initial state)

**What it must do:**
- `slider`: horizontal, range 0–100, initial value 0
- `sliderValueLabel`: displays `"slider: N"` (integer) updating as the slider moves
- A drag from `slider` (center) to `sliderValueLabel` (to its right) must move the slider thumb far enough to produce a value > 0

**macOS:**
```swift
let slider = NSSlider(value: 0, minValue: 0, maxValue: 100,
                      target: self, action: #selector(sliderMoved(_:)))
slider.setAccessibilityIdentifier("slider")
@objc func sliderMoved(_ s: NSSlider) {
    sliderValueLabel.stringValue = "slider: \(Int(s.doubleValue))"
}
```
**iOS:**
```swift
let slider = UISlider()
slider.minimumValue = 0; slider.maximumValue = 100; slider.value = 0
slider.accessibilityIdentifier = "slider"
slider.addTarget(self, action: #selector(sliderMoved), for: .valueChanged)
@objc func sliderMoved() {
    sliderValueLabel.text = "slider: \(Int(slider.value))"
}
```
**Android:**
```xml
<SeekBar android:id="@+id/slider"
         android:contentDescription="slider"
         android:max="100" android:progress="0" />
<TextView android:id="@+id/sliderValueLabel"
          android:contentDescription="sliderValueLabel"
          android:text="slider: 0" />
```
```kotlin
slider.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
    override fun onProgressChanged(sb: SeekBar, progress: Int, fromUser: Boolean) {
        sliderValueLabel.text = "slider: $progress"
    }
    override fun onStartTrackingTouch(sb: SeekBar) {}
    override fun onStopTrackingTouch(sb: SeekBar) {}
})
```

> **Drag destination:** `sliderValueLabel` is placed to the right of `slider`. The runner resolves both elements, extracts their screen-space centers, and synthesizes a drag from slider-center to label-center. The label must be positioned far enough right that the drag reliably moves the thumb past zero.

---

### 14–15. `rightClickTarget` + `ContextAction` — Context menu

**Plan exercises:** `rightClick`, `press` on context menu item, `assert value contains "context-tapped"`

**What it must do:**
- `rightClickTarget`: right-click (macOS) or long-press (iOS/Android) opens a context menu
- Context menu contains exactly one item: `"ContextAction"`
- Selecting it sets `statusLabel` to `"status: context-tapped"`

**macOS:**
```swift
// NSView subclass
override func rightMouseDown(with event: NSEvent) {
    let menu = NSMenu(); let item = NSMenuItem(title: "ContextAction", ...)
    NSMenu.popUpContextMenu(menu, with: event, for: self)
}
```
**iOS:** `UIContextMenuInteraction` (iOS 13+):
```swift
let interaction = UIContextMenuInteraction(delegate: self)
rightClickTarget.addInteraction(interaction)
// UIContextMenuInteractionDelegate:
func contextMenuInteraction(...) -> UIContextMenuConfiguration? {
    UIContextMenuConfiguration(actionProvider: { _ in
        UIMenu(children: [UIAction(title: "ContextAction") { _ in
            self.statusLabel.text = "status: context-tapped"
        }])
    })
}
```
**Android:** `registerForContextMenu` + `onCreateContextMenu`:
```kotlin
registerForContextMenu(rightClickTarget)
override fun onCreateContextMenu(menu: ContextMenu, v: View, info: ContextMenu.ContextMenuInfo?) {
    menu.add(0, 1, 0, "ContextAction")
}
override fun onContextItemSelected(item: MenuItem): Boolean {
    if (item.itemId == 1) { statusLabel.text = "status: context-tapped"; return true }
    return super.onContextItemSelected(item)
}
```

> **Selector note:** On macOS the context menu item is resolved as `{"role":"AXMenuItem","title":"ContextAction"}`. On iOS/Android the runner must expose the menu item with `accessibilityIdentifier = "contextAction"` (lowercase) or resolve it by label text. The test plan currently uses the macOS selector; iOS/Android runners should add identifier-based fallback resolution.

---

### 16. `Toggle Flag` — Menu / nav action

**Plan exercises:** `menu`, `assert value contains "flag=true"`, `assert marked equals "true"`

**What it must do:**
- Toggles a boolean flag
- When on: `statusLabel` contains `"flag=true"`; the menu item itself reports `marked = true` (checkmark present)
- Accessible via `menu` action with path `["View", "Toggle Flag"]`

**macOS:** `NSMenuItem` in the `View` submenu of the main menu bar; set `state = .on/.off` to control the checkmark.

**iOS:** No persistent menu bar. Map `["View", "Toggle Flag"]` to a `UIBarButtonItem` or `UIAlertController` action sheet. The runner's `menu` implementation for iOS traverses navigation elements by path. The `marked` property maps to whether the button's image or title indicates the "on" state (runner-defined mapping).

**Android:** Options menu item in the `View` group. `menu` path `["View","Toggle Flag"]` maps to `R.id.action_toggle_flag`. `marked` maps to `item.isChecked`.

---

### 17 & 18. `modeSegment` + `segmentLabel` — Segmented control

**Plan exercises:** `press` on child `AXRadioButton` by index, `assert value equals "segment: N"`

**What it must do:**
- 3 segments labelled Alpha (index 0), Beta (index 1), Gamma (index 2)
- Selecting a segment updates `segmentLabel` to `"segment: N"` (the zero-based index)
- Starts with index 0 selected

**macOS (AppKit)**
```swift
let modeSegment = NSSegmentedControl(labels: ["Alpha", "Beta", "Gamma"],
                                     trackingMode: .selectOne, target: self,
                                     action: #selector(segmentChanged))
modeSegment.setAccessibilityIdentifier("modeSegment")

let segmentLabel = NSTextField(labelWithString: "segment: 0")
segmentLabel.setAccessibilityIdentifier("segmentLabel")

@objc func segmentChanged() {
    segmentLabel.stringValue = "segment: \(modeSegment.selectedSegment)"
}
// Target children by index — AXRadioButton children have no AX title on macOS.
```

**iOS (UIKit)**
```swift
let modeSegment = UISegmentedControl(items: ["Alpha", "Beta", "Gamma"])
modeSegment.accessibilityIdentifier = "modeSegment"
modeSegment.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
let segmentLabel = UILabel(); segmentLabel.accessibilityIdentifier = "segmentLabel"
@objc func segmentChanged() {
    segmentLabel.text = "segment: \(modeSegment.selectedSegmentIndex)"
}
// XCTest: target modeSegment by identifier, call adjust(toNormalizedSliderPosition:)
// or tap the segment element directly once it's resolved.
```

**Android (XML + Kotlin)**
```xml
<RadioGroup android:id="@+id/modeSegment"
            android:contentDescription="modeSegment"
            android:orientation="horizontal">
    <RadioButton android:text="Alpha" />
    <RadioButton android:text="Beta" />
    <RadioButton android:text="Gamma" />
</RadioGroup>
<TextView android:id="@+id/segmentLabel"
          android:contentDescription="segmentLabel"
          android:text="segment: 0" />
```
```kotlin
modeSegment.setOnCheckedChangeListener { group, checkedId ->
    val index = group.indexOfChild(group.findViewById(checkedId))
    segmentLabel.text = "segment: $index"
}
```

---

### 19 & 20. `colorPicker` + `pickerLabel` — Popup button / dropdown

**Plan exercises:** `press` to open, `press` on `AXMenuItem` by title to select, `assert value equals "pick: <color>"`

**What it must do:**
- 3 items: Red, Green, Blue; starts on Red
- Selecting an item updates `pickerLabel` to `"pick: <title>"`

**macOS (AppKit)**
```swift
let colorPicker = NSPopUpButton(frame: .zero, pullsDown: false)
colorPicker.addItems(withTitles: ["Red", "Green", "Blue"])
colorPicker.setAccessibilityIdentifier("colorPicker")
colorPicker.target = self; colorPicker.action = #selector(pickerChanged)

let pickerLabel = NSTextField(labelWithString: "pick: Red")
pickerLabel.setAccessibilityIdentifier("pickerLabel")

@objc func pickerChanged() {
    pickerLabel.stringValue = "pick: \(colorPicker.titleOfSelectedItem ?? "")"
}
// Plan: press colorPicker (opens menu), then press AXMenuItem by title.
// setValue writes AX value but fires no action — use press+press for label update.
```

**iOS (UIKit)**
```swift
// Use UIPickerView or UIMenu (iOS 14+).
let pickerButton = UIButton(); pickerButton.accessibilityIdentifier = "colorPicker"
let menu = UIMenu(children: ["Red","Green","Blue"].map { title in
    UIAction(title: title) { [weak self] _ in
        self?.pickerLabel.text = "pick: \(title)"
    }
})
pickerButton.menu = menu; pickerButton.showsMenuAsPrimaryAction = true
```

**Android (XML + Kotlin)**
```xml
<Spinner android:id="@+id/colorPicker"
         android:contentDescription="colorPicker" />
```
```kotlin
val adapter = ArrayAdapter(this, android.R.layout.simple_spinner_item,
                           listOf("Red","Green","Blue"))
colorPicker.adapter = adapter
colorPicker.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
    override fun onItemSelected(p: AdapterView<*>, v: View?, pos: Int, id: Long) {
        pickerLabel.text = "pick: ${adapter.getItem(pos)}"
    }
    override fun onNothingSelected(p: AdapterView<*>) {}
}
```

---

### 21 & 22. `quantityStepper` + `quantityLabel` — Stepper

**Plan exercises:** `press` on child `AXButton` by index (0=increment, 1=decrement), `assert value equals "qty: N"`

**What it must do:**
- Range 0–10, step 1, starts at 0
- Increment button (index 0) adds 1; decrement button (index 1) subtracts 1
- Updates `quantityLabel` to `"qty: N"`

**macOS (AppKit)**
```swift
let quantityStepper = NSStepper()
quantityStepper.minValue = 0; quantityStepper.maxValue = 10; quantityStepper.increment = 1
quantityStepper.setAccessibilityIdentifier("quantityStepper")
quantityStepper.target = self; quantityStepper.action = #selector(stepperChanged)

let quantityLabel = NSTextField(labelWithString: "qty: 0")
quantityLabel.setAccessibilityIdentifier("quantityLabel")

@objc func stepperChanged() {
    quantityLabel.stringValue = "qty: \(Int(quantityStepper.intValue))"
}
// AX children: index 0 = increment (top button), index 1 = decrement (bottom button).
// Do NOT rely on child button titles — they are localization-dependent.
```

**iOS (UIKit)**
```swift
let quantityStepper = UIStepper()
quantityStepper.minimumValue = 0; quantityStepper.maximumValue = 10
quantityStepper.accessibilityIdentifier = "quantityStepper"
quantityStepper.addTarget(self, action: #selector(stepperChanged), for: .valueChanged)
@objc func stepperChanged() {
    quantityLabel.text = "qty: \(Int(quantityStepper.value))"
}
```

**Android (XML + Kotlin)**
```xml
<!-- Android has no built-in Stepper; use two buttons -->
<Button android:id="@+id/stepperDecrement" android:text="-"
        android:contentDescription="stepper-decrement" />
<TextView android:id="@+id/quantityLabel"
          android:contentDescription="quantityLabel" android:text="qty: 0" />
<Button android:id="@+id/stepperIncrement" android:text="+"
        android:contentDescription="stepper-increment" />
```
```kotlin
var qty = 0
stepperIncrement.setOnClickListener { qty = (qty + 1).coerceAtMost(10); updateQty() }
stepperDecrement.setOnClickListener { qty = (qty - 1).coerceAtLeast(0); updateQty() }
fun updateQty() { quantityLabel.text = "qty: $qty" }
// Android runner: target by identifier "stepper-increment" / "stepper-decrement"
// rather than by index, since the native view hierarchy differs from AXIncrementor.
```

---

### 23 & 24. `uploadProgress` + `advanceButton` — Progress indicator

**Plan exercises:** `assert value equals/greaterThan/lessThan`, `click` to advance, `assert value equals "1.0"`

**What it must do:**
- Deterministic value (0.0–1.0); starts at 0.5
- Clicking `advanceButton` sets it to 1.0
- AX value is the numeric string `"0.5"` / `"1.0"` (not a percentage)

**macOS (AppKit)**
```swift
let uploadProgress = NSProgressIndicator()
uploadProgress.style = .bar; uploadProgress.minValue = 0; uploadProgress.maxValue = 1
uploadProgress.doubleValue = 0.5
uploadProgress.setAccessibilityIdentifier("uploadProgress")

let advanceButton = NSButton(title: "Advance", target: self, action: #selector(advance))
advanceButton.setAccessibilityIdentifier("advanceButton")

@objc func advance() { uploadProgress.doubleValue = 1.0 }
// AX value is a Double string — assert with op "equals" / "greaterThan" / "lessThan".
```

**iOS (UIKit)**
```swift
let uploadProgress = UIProgressView(); uploadProgress.progress = 0.5
uploadProgress.accessibilityIdentifier = "uploadProgress"
// XCTest reads progress as value string "50%" by default; normalize to "0.5"
// by overriding accessibilityValue:
uploadProgress.accessibilityValue = String(format: "%.1f", uploadProgress.progress)
let advanceButton = UIButton(); advanceButton.accessibilityIdentifier = "advanceButton"
advanceButton.addTarget(self, action: #selector(advance), for: .touchUpInside)
@objc func advance() {
    uploadProgress.progress = 1.0
    uploadProgress.accessibilityValue = "1.0"
}
```

**Android (XML + Kotlin)**
```xml
<ProgressBar android:id="@+id/uploadProgress"
             android:contentDescription="uploadProgress"
             style="?android:attr/progressBarStyleHorizontal"
             android:max="100" android:progress="50" />
```
```kotlin
// Appium reads progress as integer 0-100. Android runner must normalize:
// value = (progress / 100.0).toString()
advanceButton.setOnClickListener { uploadProgress.progress = 100 }
```

---

### 25. `notesArea` — Multi-line text area

**Plan exercises:** `type` with `\n` (newline), `assert value contains`, `setValue` (direct replace), `assert value equals`

**What it must do:**
- Editable multi-line text area, starts empty
- `type` with `\n` inserts a line break
- `setValue` replaces the entire content (no append)

**macOS (AppKit)**
```swift
let scrollWrapper = NSScrollView(); scrollWrapper.hasVerticalScroller = true
// Do NOT set accessibility identifier on the scroll wrapper —
// it interferes with the text area's own identifier resolution.
scrollWrapper.setAccessibilityElement(false)

let notesArea = NSTextView()
notesArea.setAccessibilityIdentifier("notesArea")
notesArea.isEditable = true; notesArea.isRichText = false
scrollWrapper.documentView = notesArea
// setValue writes kAXValueAttribute directly — works for NSTextView.
// clear+type via Cmd+A+Delete is unreliable on NSTextView; prefer setValue.
```

**iOS (UIKit)**
```swift
let notesArea = UITextView()
notesArea.accessibilityIdentifier = "notesArea"
notesArea.isEditable = true
// XCTest typeText() appends; use clearAndEnterText helper for replace:
// element.tap(); element.clearText(); element.typeText("New content")
```

**Android (XML + Kotlin)**
```xml
<EditText android:id="@+id/notesArea"
          android:contentDescription="notesArea"
          android:inputType="textMultiLine"
          android:minLines="3" />
```

---

### 26. `termsLink` — Tappable link

**Plan exercises:** `assert value exists`, `click`, `assert statusLabel contains "link-tapped"`

**What it must do:**
- Visually a blue underlined label ("Terms of Service")
- Click/tap sets `statusLabel` to `"status: link-tapped"`
- AX role is `AXLink` (macOS) / `link` (iOS) / custom (Android)

**macOS (AppKit)**
```swift
final class TappableLink: NSView {
    override func mouseDown(with event: NSEvent) {
        statusLabel.stringValue = "status: link-tapped"
    }
    override func accessibilityRole() -> NSAccessibility.Role? { .link }
    override func isAccessibilityElement() -> Bool { true }
}
let termsLink = TappableLink()
termsLink.setAccessibilityIdentifier("termsLink")
```

**iOS (UIKit)**
```swift
// Use a UIButton styled as a link, or a UILabel with a tap recognizer.
let termsLink = UIButton(type: .system)
termsLink.setTitle("Terms of Service", for: .normal)
termsLink.accessibilityIdentifier = "termsLink"
termsLink.accessibilityTraits = .link
termsLink.addTarget(self, action: #selector(linkTapped), for: .touchUpInside)
@objc func linkTapped() { statusLabel.text = "status: link-tapped" }
```

**Android (XML + Kotlin)**
```xml
<TextView android:id="@+id/termsLink"
          android:contentDescription="termsLink"
          android:text="Terms of Service"
          android:textColor="@color/blue"
          android:clickable="true"
          android:focusable="true" />
```
```kotlin
termsLink.setOnClickListener { statusLabel.text = "status: link-tapped" }
```

---

### 27–31. `fileTable` + row cells + `tableSelLabel` — Table / list

**Plan exercises:** `assert count equals "3"` (scoped), `click` row by identifier, `assert value equals "table-sel: <name>"`, `assert value exists`

**What it must do:**
- 3 rows: document.pdf, photo.jpg, notes.txt (in that order)
- Each row's accessible cell has identifier `"row-<filename>"`
- Clicking a row updates `tableSelLabel` to `"table-sel: <filename>"`
- Starts with no row selected (`tableSelLabel` = `"table-sel: none"`)

**macOS (AppKit)**
```swift
let fileTable = NSTableView(); fileTable.setAccessibilityIdentifier("fileTable")
let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("col"))
fileTable.addTableColumn(column)

// In NSTableViewDelegate.tableView(_:viewFor:row:):
func tableView(_ tv: NSTableView, viewFor col: NSTableColumn?, row: Int) -> NSView? {
    let cell = NSTextField(labelWithString: files[row])
    cell.setAccessibilityIdentifier("row-\(files[row])")  // e.g. "row-document.pdf"
    return cell
}
// In tableViewSelectionDidChange:
func tableViewSelectionDidChange(_ notification: Notification) {
    let row = fileTable.selectedRow
    tableSelLabel.stringValue = row >= 0 ? "table-sel: \(files[row])" : "table-sel: none"
}
```

**iOS (UIKit)**
```swift
// UITableView — set accessibilityIdentifier on the cell's contentView label.
override func tableView(_ tv: UITableView,
                        cellForRowAt ip: IndexPath) -> UITableViewCell {
    let cell = tv.dequeueReusableCell(withIdentifier: "cell", for: ip)
    let filename = files[ip.row]
    cell.textLabel?.text = filename
    cell.textLabel?.accessibilityIdentifier = "row-\(filename)"
    return cell
}
override func tableView(_ tv: UITableView, didSelectRowAt ip: IndexPath) {
    tableSelLabel.text = "table-sel: \(files[ip.row])"
}
```

**Android (XML + Kotlin)**
```kotlin
// RecyclerView — set contentDescription on each item view.
override fun onBindViewHolder(holder: VH, position: Int) {
    val filename = files[position]
    holder.label.text = filename
    holder.itemView.contentDescription = "row-$filename"
    holder.itemView.setOnClickListener {
        tableSelLabel.text = "table-sel: $filename"
    }
}
```

---

### 32–34. `alertButton` + `confirmButton` + `cancelButton` — Alert / modal sheet

**Plan exercises:** `click` alertButton, `waitFor role=AXSheet present:true`, `press` confirmButton by identifier, `waitFor role=AXSheet present:false`, `assert statusLabel contains "alert-confirmed"`

**What it must do:**
- `alertButton` presents a modal with title `"Are you sure?"` and two buttons
- `confirmButton` sets `statusLabel` to `"status: alert-confirmed"` and dismisses
- `cancelButton` sets `statusLabel` to `"status: alert-cancelled"` and dismisses
- The modal must appear in the AX tree as `AXSheet` (macOS) / modal view (iOS) / AlertDialog (Android)

**macOS (AppKit)**
```swift
let alertButton = NSButton(title: "Show Alert", target: self, action: #selector(showAlert))
alertButton.setAccessibilityIdentifier("alertButton")

@objc func showAlert() {
    let alert = NSAlert()
    alert.messageText = "Are you sure?"
    alert.addButton(withTitle: "Confirm")  // index 0
    alert.addButton(withTitle: "Cancel")   // index 1
    // Set identifiers AFTER adding buttons so the NSButton objects exist:
    alert.buttons[0].setAccessibilityIdentifier("confirmButton")
    alert.buttons[1].setAccessibilityIdentifier("cancelButton")
    alert.beginSheetModal(for: window!) { response in
        if response == .alertFirstButtonReturn {
            self.statusLabel.stringValue = "status: alert-confirmed"
        } else {
            self.statusLabel.stringValue = "status: alert-cancelled"
        }
    }
}
// waitFor role=AXSheet present:true polls until the sheet attaches.
// waitFor role=AXSheet present:false polls until it disappears after button press.
```

**iOS (UIKit)**
```swift
@objc func showAlert() {
    let alert = UIAlertController(title: "Are you sure?", message: nil,
                                  preferredStyle: .alert)
    let confirm = UIAlertAction(title: "Confirm", style: .default) { _ in
        self.statusLabel.text = "status: alert-confirmed"
    }
    let cancel = UIAlertAction(title: "Cancel", style: .cancel) { _ in
        self.statusLabel.text = "status: alert-cancelled"
    }
    // XCTest targets alert buttons by their title — use title as selector fallback.
    alert.addAction(confirm); alert.addAction(cancel)
    present(alert, animated: true)
}
```

**Android (XML + Kotlin)**
```kotlin
alertButton.setOnClickListener {
    AlertDialog.Builder(this)
        .setTitle("Are you sure?")
        .setPositiveButton("Confirm") { _, _ ->
            statusLabel.text = "status: alert-confirmed" }
        .setNegativeButton("Cancel") { _, _ ->
            statusLabel.text = "status: alert-cancelled" }
        .show()
}
// Appium targets dialog buttons by text content; set contentDescription
// "confirmButton" / "cancelButton" on the inflated button views if possible.
```

---

### 35 & 36. `lockedButton` + `disabledLabel` — Disabled element

**Plan exercises:** `assert value exists`, `assert enabled equals "false"`, `assert value equals "locked: true"`

**What it must do:**
- `lockedButton` is visible but non-interactive (`isEnabled = false`)
- It must appear in the AX tree (not hidden) so `exists` returns true
- Its `enabled` property must read `"false"`
- `disabledLabel` is a static label with value `"locked: true"`

**macOS (AppKit)**
```swift
let lockedButton = NSButton(title: "Locked", target: nil, action: nil)
lockedButton.isEnabled = false
lockedButton.setAccessibilityIdentifier("lockedButton")

let disabledLabel = NSTextField(labelWithString: "locked: true")
disabledLabel.setAccessibilityIdentifier("disabledLabel")
// NSButton with isEnabled=false remains in the AX tree and reports
// kAXEnabledAttribute = false — no extra configuration needed.
```

**iOS (UIKit)**
```swift
let lockedButton = UIButton(type: .system)
lockedButton.setTitle("Locked", for: .normal)
lockedButton.isEnabled = false
lockedButton.accessibilityIdentifier = "lockedButton"
// isEnabled=false sets isAccessibilityElement to true automatically;
// XCTest sees it but isEnabled returns false.
let disabledLabel = UILabel(); disabledLabel.text = "locked: true"
disabledLabel.accessibilityIdentifier = "disabledLabel"
```

**Android (XML + Kotlin)**
```xml
<Button android:id="@+id/lockedButton"
        android:text="Locked"
        android:enabled="false"
        android:contentDescription="lockedButton" />
<TextView android:id="@+id/disabledLabel"
          android:text="locked: true"
          android:contentDescription="disabledLabel" />
```

---

## Platform-Runner Mapping Table

Actions where the platform runner must translate the plan concept into a different native mechanism:

| Plan action | macOS implementation | iOS implementation | Android implementation |
|---|---|---|---|
| `click` | CGEvent left mouse down/up | `XCUIElement.tap()` / touch event | Appium `tap` |
| `doubleClick` | CGEvent clickCount=2 | `XCUIElement.doubleTap()` | Appium `doubleTap` |
| `rightClick` | CGEvent right mouse down/up | Long-press gesture (triggers context menu) | Long-press event |
| `press` | AX `kAXPressAction` | `XCUIElement.tap()` on button | Appium `tap` |
| `type` | CGEvent keyboard + unicode fallback | `XCUIElement.typeText()` | Appium `sendKeys` |
| `keyPress` | CGEvent virtual key + modifiers | `XCUIElement.typeText()` with special chars | Appium key events |
| `setValue` | AX `kAXValueAttribute` write | `XCUIElement.adjust(toNormalizedSliderPosition:)` or direct value | Appium `setValue` |
| `scroll` | CGEvent scroll wheel | `XCUIElement.swipeUp/Down()` | Appium `scroll` |
| `drag` | CGEvent mouse-down + drag + up | `XCUIElement.press(forDuration:thenDragTo:)` | Appium `dragAndDrop` |
| `menu` | Walk `NSMenu` / `AXMenuBar` by path | Find bar button / action sheet by path | Find options menu item by path |
| `assertPixel` | ScreenCaptureKit pixel sample | XCTest screenshot + pixel read | Appium screenshot + pixel read |
| `assertRegion` | ScreenCaptureKit region sample | XCTest screenshot + region average | Appium screenshot + region average |
| `snapshot` | ScreenCaptureKit element crop + NCC diff | XCTest screenshot crop + NCC diff | Appium screenshot crop + NCC diff |
| `screenshot` | ScreenCaptureKit element/display capture | XCTest `screenshot()` | Appium `getScreenshot` |
| `waitFor` | AX tree polling | XCTest `waitForExistence(timeout:)` | Appium `waitForElement` |
| `assert value` | `kAXValueAttribute` string | `XCUIElement.value` | Appium `getAttribute("text")` |
| `assert title` | `kAXTitleAttribute` string | `XCUIElement.label` | Appium `getAttribute("content-desc")` |
| `assert enabled` | `kAXEnabledAttribute` bool | `XCUIElement.isEnabled` | Appium `isEnabled()` |
| `assert focused` | `kAXFocusedAttribute` bool | `XCUIElement.hasFocus` | Appium `isFocused()` |
| `assert marked` | `kAXMenuItemMarkChar` non-empty | `XCUIElement.value == "1"` (switch) / custom | `MenuItem.isChecked` |
| `assert position` | `kAXPositionAttribute` CGPoint | `XCUIElement.frame.origin` | Appium `getLocation()` |
| `assert size` | `kAXSizeAttribute` CGSize | `XCUIElement.frame.size` | Appium `getSize()` |
| `assert count` | AX tree count query | XCTest query count | Appium `findElements().size()` |
| `terminate` | `NSRunningApplication.terminate()` | `XCUIApplication.terminate()` | Appium `closeApp()` |
| `wait` | `Thread.sleep` | `Thread.sleep` | `Thread.sleep` |
| `launch` | `NSWorkspace.openApplication` | `XCUIApplication.launch()` | Appium `launchApp()` |
