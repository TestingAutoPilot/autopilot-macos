# AutoPilot Cockpit — Design Spec

_Status: approved (brainstorming). Next: implementation plan under `docs/plans/`._

---

## Context

Users of AutoPilot today have only a CLI (`autopilot`), an MCP server, and JSON plan
files. There is no visual way to see what the framework sees in an app under test,
to build a plan without hand-writing JSON, or to watch a run execute step by step.
The user asked for a full GUI **"cockpit"** — an IDE-style app that unifies three
jobs: **Inspect** (browse the live accessibility tree of the target app),
**Author** (build/edit plans visually), and **Run** (drive a plan and watch live
pass/fail). The goal is to make AutoPilot approachable and observable, turning an
expert CLI into a tool a person can drive with their eyes.

The cockpit is a GUI that **consumes** the framework — it does not live inside the
headless, platform-agnostic `autopilot-core` library (that would drag SwiftUI/AppKit
into a library whose CI purity gate forbids platform imports). It lives in
`autopilot-macos`, where the real Accessibility driving already exists.

## Decisions locked (via brainstorming)

- **Scope:** all three modes (Inspect / Author / Run), designed as one cohesive app
  up front, delivered in phases.
- **Home + ship:** new `AutopilotCockpit.app` target **inside `autopilot-macos`**;
  links `MacOSDriver` + `AutopilotCore` directly (no CLI shell-out); bundled into the
  existing release tarball and installed by the Homebrew formula alongside the CLI;
  version tracks the CLI line.
- **Live run:** add an **additive, backward-compatible** progress observer to
  `PlanRunner` in `autopilot-core` — the **only** `-core` change in the project.
- **Round-one boundary:** Inspect + Run **complete**; Author **basic** (edit step
  list, selector-from-Inspect, save valid JSON). Visual per-action editor,
  drag-reorder polish, run history/diffing → **phase 2**.
- **Signing:** ad-hoc sign the `.app` now (like the drag helper); Developer ID +
  notarization is a later hardening step.
- **Release gate:** **plan + build only. NO tag / GitHub release / tap bump / brew
  publish until an explicit "go"** — same hard gate as v3.1.2.

---

## 1. Architecture & module boundaries

```
AutopilotCockpit  (SwiftUI .app target — NEW, in autopilot-macos)
    │  imports
    ├── MacOSDriver     ← live AX tree, resolve/find, actions, capture, launch/attach
    └── AutopilotCore   ← Plan model, PlanParser, PlanRunner, PlanLinter, Report,
                          SelectorSuggester, StepLevel, RunObserver (new)
```

The cockpit is a thin, well-structured UI over **proven engines** — every capability
the three panels need is already public API. No engine is reimplemented; nothing
shells out to the CLI.

**Capability reuse map (all confirmed public during exploration):**

| Panel   | Reuses |
|---------|--------|
| Inspect | `AXTree.application(pid:)`, `AXTree.snapshot()`, `MacAXResolver().findAll/count`, `SelectorSuggester.suggest()` |
| Run     | `PlanParser.parse()`, `PlanRunner.run()`, `Report`/`StepResult`, `Reporter.humanSummary()`, `LevelBreakdown` |
| Author  | `Plan`/`Step`/`Selector`/`Assertion` (Codable), `PlanLinter.lint()`, `SelectorSuggester` |

**Single seam — `CockpitEngine`** (an `@Observable`/`ObservableObject`): owns the one
`MacOSDriver` instance and the current `LaunchedHandle`; it is the *only* type that
touches the driver. SwiftUI views call the engine, never the driver. This isolates
all framework interaction in one auditable, testable place and serializes driver
access (one target, one operation at a time).

## 2. The one `-core` change — `PlanRunner` progress observer

`PlanRunner.run(_:options:)` is currently synchronous and returns a single final
`Report` with no per-step callbacks. To light up live pass/fail without the cockpit
reimplementing the run loop (which would drift from the real runner), add one small
additive hook to `autopilot-core`:

```swift
// New in AutopilotCore — lightweight passive observer.
public protocol RunObserver: AnyObject, Sendable {
    func runWillStart(plan: Plan)
    func stepWillStart(_ step: Step, index: Int, of total: Int)
    func stepDidFinish(_ result: StepResult, index: Int)   // fires as each step completes
    func runDidFinish(_ report: Report)
}
public extension RunObserver { /* empty default impls for all four */ }
```

`RunOptions` gains one optional field:

```swift
public var observer: RunObserver?   // defaults to nil
```

Inside `run(...)`, at the points where each `StepResult` is already computed (including
level-filtered **skipped** steps, so the UI can grey them), call
`options.observer?.stepDidFinish(result, index:)`. The runner's logic, ordering, and
return value are otherwise unchanged — the observer is a passive tap.

**Why safe / correct:**
- **Backward compatible** — `observer` defaults to `nil`; CLI `Run`, MCP `run_plan`,
  iOS, Android, and all existing tests compile and behave identically. Empty protocol
  defaults let the cockpit implement only the callbacks it uses.
- **No duplicated run logic** — cockpit observes the *real* runner (the
  research-before-fighting-framework lesson: extend the engine, don't fight it).
- **Every platform benefits** — iOS/Android and any future consumer get live progress
  for free.
- New observer gets its own tests in `autopilot-core` against the existing `FakeDriver`.

**Threading:** cockpit runs `PlanRunner.run()` on a background `Task`; observer
callbacks hop to `@MainActor` before touching SwiftUI state. Screenshots/AX-dumps are
already written to the artifacts dir; the observer carries their paths and the UI
loads them from disk.

## 3. Components — panels + shell

Single window: a mode switcher `[Inspect] [Author] [Run]` + a shared **target bar**
(pick/attach/launch the app under test, connection status). All three modes operate on
the same attached target via the shared `CockpitEngine`.

**Shared shell**
- `CockpitApp` (`@main`) → `RootView` (mode switcher + target bar + active panel).
- `TargetBar` — running-app dropdown or launch-by-bundleId/path; `●/○` status;
  re-attach. Drives `engine.attach(...)` / `engine.launch(...)`.
- `CockpitEngine` — owns `MacOSDriver` + current `LaunchedHandle`; only caller of the
  driver; serializes access.

**Inspect (complete in round one)**
- `AXTreeView` — hierarchical outline. `AXTree.snapshot()` returns a **flat** node
  list; a **pure** cockpit-side `TreeBuilder` reconstructs parent/child nesting for
  display (pure → unit-testable, no GUI).
- `ElementDetail` — role, identifier, title, value, frame, enabled/focused of the
  selected node.
- **Copy selector** / **Suggest selector** via `SelectorSuggester.suggest()`.
- Search/filter + on-demand **Refresh** (no continuous polling in round one — avoids
  hammering the AX API; matches the polling/headless lesson).

**Run (complete in round one)**
- `PlanPicker` — choose a `.json` plan; parse/lint status via `PlanParser` +
  `PlanLinter`; Run disabled until clean.
- `RunControlBar` — Run button, **level tier** selector (happyPath / integrationSuite /
  tryToBreakIt → `RunOptions.maxLevel`), keep-going toggle.
- `StepListView` — one row per step, live status light
  (pending → running → pass/fail/skipped) driven by the §2 observer; duration +
  message per row.
- `ArtifactPane` — screenshot + AX-dump for the selected step, loaded from the
  artifacts dir.
- `ReportSummary` — `Reporter.humanSummary()` + `LevelBreakdown`.

**Author (basic in round one; deepened in phase 2)**
- Loads a plan into an **editable step list**: reorder, add/delete, edit each step's
  action/selector/assertion via **basic forms** (rich per-action visual editor → phase 2).
- **Selector-from-Inspect** — select a node in Inspect → "use as selector" fills the
  step's target. The key cross-panel integration.
- **Save** back to JSON by round-tripping the Codable `Plan` model (stays
  schema-valid); live `PlanLinter` findings shown inline.

**Explicit round-one boundary:** Inspect + Run complete; Author = load / edit-basic /
save + selector-from-Inspect. Deferred to **phase 2**: full visual action editor,
drag-reorder polish, run history + report diffing. The whole design is structured so
phase 2 slots in without rework.

## 4. Data flow, errors, testing, distribution

**Live-run data flow (the one tricky path):**
1. Pick plan → `PlanParser.parse()` → `Plan` (parse/lint errors inline; Run gated).
2. Run → build `RunOptions(observer: self, maxLevel: <tier>, artifactsDir: <temp>)`;
   call `PlanRunner.run()` on a background `Task`.
3. Each step completes → `stepDidFinish(result, index:)` → hop to `@MainActor` →
   update that row's light + duration.
4. On failure the runner has already written screenshot/AX-dump to `artifactsDir`;
   observer carries paths; `ArtifactPane` loads from disk.
5. `runDidFinish(report:)` → `ReportSummary` renders summary + `LevelBreakdown`.

Inspect/Author are simple request/response (view → engine → driver → render). The
engine serializes driver access; during a live run, Inspect/Author interactions that
would move the mouse are disabled.

**Error handling (surfaced, never swallowed):**
- **No AX permission** → first-run banner with exact System Settings path + recheck
  button (reuses `MacOSDriver.Permissions` + `accessibilityInstructions()`); app inert
  but honest until granted.
- **Attach/launch failure, target quit mid-run, selector not found, parse/lint error**
  → each maps to a specific human-readable message (framework's `TargetingError` /
  `PlanError` are already friendly). Every throwing driver call is surfaced; nothing
  caught-and-ignored.
- **Run aborted** (target crash) → observer still fires `runDidFinish` with the partial
  report; UI shows what completed and why it stopped.

**Testing:**
- **Pure logic → headless unit tests:** `TreeBuilder` (flat→nested), selector-string
  formatting, plan round-trip (load→edit→save→re-parse equal), lint surfacing.
- **Engine against `FakeDriver`:** `CockpitEngine` + `RunObserver` wiring tested
  deterministically (observer fires N times, in order, correct statuses) — no real
  WindowServer; CI-safe.
- **Live-GUI smoke** (attach to TestHostApp fixture, dump tree, run a tiny plan) →
  gated to the real-display self-hosted runner; **poll + skip-when-headless** per the
  known live-GUI flake lesson; not on the hosted runner.
- **`-core` observer** → own tests in `autopilot-core` against its `FakeDriver`.

**Distribution (all held behind explicit "go"):**
- `release.sh` gains a step: build `AutopilotCockpit.app`, **ad-hoc sign** (Developer
  ID/notarize later), add to the tarball.
- Homebrew formula installs it (recommend `bin.install "AutopilotCockpit.app"` next to
  the CLI, consistent with the drag helper; `/Applications` symlink is the alternative
  — settled in the plan). Caveats point users at granting AX permission to the app +
  how to launch it.
- Cockpit version tracks the CLI line. **Nothing tags/publishes until "go".**

---

## Delivery phases

- **Phase 0 — `-core`:** add `RunObserver` + `RunOptions.observer`; wire
  `stepDidFinish` (incl. skipped); tests against `FakeDriver`. (autopilot-core branch,
  unreleased.)
- **Phase 1 — shell + Inspect:** app target, `CockpitEngine`, `TargetBar`,
  `AXTreeView`/`ElementDetail`, `TreeBuilder`, selector copy/suggest, permission
  banner.
- **Phase 2 — Run:** `PlanPicker`, `RunControlBar`, `StepListView` (live via observer),
  `ArtifactPane`, `ReportSummary`.
- **Phase 3 — Author (basic):** editable step list, basic forms,
  selector-from-Inspect, save + inline lint.
- **Phase 4 — packaging:** `release.sh` + formula changes, ad-hoc sign; **staged,
  unreleased** until "go".
- **Later (phase 2 of Author):** visual action editor, drag-reorder, run history/diff,
  Developer ID + notarization.

## Verification (end-to-end, once built)

- `swift build` green in autopilot-macos incl. the new target; `-core` builds with the
  observer and passes its purity gate.
- Headless: all pure + FakeDriver tests pass on the hosted CI runner.
- Live (self-hosted / this machine): launch cockpit → grant AX → attach to TestHostApp
  fixture → Inspect shows the tree, copy a selector → Run a small fixture plan → step
  lights update live, final report matches a CLI `autopilot run` of the same plan →
  Author loads that plan, edit a step via selector-from-Inspect, save, re-lint clean.
- Cross-check: a plan authored in the cockpit runs identically under the CLI (proves
  no engine drift).

## Constraints carried into implementation

- **NEVER touch medit** — this project is autopilot-macos + autopilot-core + the tap only.
- Git author always `jschwefel@coldboreballisticsllc.com`; never `-c` override.
- Hard release gate: no tag/release/tap/brew-publish without explicit "go".
- No historical/impl docs shipped in the tree beyond the spec/plan; git is the archive.
- Debug prints guarded; no spaces in filenames; scripts follow one-task/one-entrypoint.
