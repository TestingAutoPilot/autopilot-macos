# AutoPilot `exec` step — Design Spec

**Date:** 2026-07-04
**Branch:** `feature/ap-feedback` (autopilot-core + autopilot-macos)
**Status:** approved in brainstorming; ready for implementation plan.

## Context

medit's field-report re-validation named five single-plan coverage gaps. Three
are inherent single-plan limits or the existing `attach:true` pattern; **two are
real AutoPilot capability gaps**:

1. **Trigger an external file-change mid-run** (to exercise medit's file-watcher
   reload banner). A plan cannot mutate a file on disk between steps.
2. **Verify a Save wrote the correct bytes to disk** mid-plan. A plan cannot read
   a file's contents.

A related pair (Find-in-All-Tabs / Print setup) also benefits from being able to
stage state out-of-band from within the plan.

AutoPilot is a testing/automation tool: the plan author already fully drives the
machine under test, so a shell escape is a normal, expected capability (Playwright,
XCUITest-via-scripts, `make`-driven suites all have one) — not a new privilege
boundary. A single general `exec` step subsumes both gaps (and future mid-plan
setup/teardown/side-effect checks) in one concept, and is preferable to narrow
`writeFile`/`assertFile` primitives that would be redundant once `exec` exists.

## Decisions locked (via brainstorming)

- **One `exec` step**, not narrow file primitives.
- **Invocation:** accept EITHER `command` (shell string via `/bin/sh -c`) OR
  `argv` (array, run directly, no shell). Exactly one required.
- **Semantics:** a bare `exec` (no `assert`) **always passes** — a pure
  setup/teardown lever; exit code is ignored. An `exec` **with an `assert`** fails
  iff the assert fails. Gating is always explicit.
- **Readable assert properties:** `stdout`, `stderr`, `exitCode` — exec-scoped and
  **target-less** (same pattern as `clipboard`).
- **Timeout:** bounded by the step/plan `timeoutMs`; on expiry the process group is
  killed and the step **fails**. No run ever hangs.
- **Distribution gate:** plan + build only. No tag / release / tap bump until an
  explicit "go" (the standing hard gate).

## 1. Architecture & module boundary

`exec` shells out to the OS, so **execution** lives in the **macOS driver** (via
`Foundation.Process`), behind the `AppDriver` protocol — like `readClipboard` /
`listMenu`. The `Action.exec` case, `ActionArgs` fields, parser validation, and the
new assert properties are **platform-agnostic** and live in **core**, keeping
core's purity gate clean (no `Process` import in core).

One new `AppDriver` method, with a **default implementation** so existing conformers
(iOS/Android/Fakes) don't break:

```swift
public struct ProcessResult: Sendable {
    public let stdout: String
    public let stderr: String
    public let exitCode: Int
}

// on AppDriver, with a default impl that throws "exec unsupported on this platform":
func runProcess(command: String?, argv: [String]?, timeoutMs: Int,
                workingDir: String?) throws -> ProcessResult
```

`PlanRunner` gains an `exec` branch that calls `runProcess`, then, if an assert is
attached, evaluates it against the captured `stdout`/`stderr`/`exitCode`; with no
assert, the step passes regardless of exit.

## 2. Plan schema

**`Action`:** add `case exec` to core's enum.

**`ActionArgs`** (new optional fields, matching the existing flat bag):
- `command: String?` — shell string, run via `/bin/sh -c`.
- `argv: [String]?` — program + args, run directly (no shell).
- Exactly one of `command`/`argv` required (parser-enforced: not both, not
  neither). Process bound reuses the existing step/plan `timeoutMs`.

**`AssertProperty`** (new readable, exec-scoped, target-less):
- `stdout` — captured standard output, trimmed of one trailing newline.
- `stderr` — captured standard error, trimmed of one trailing newline.
- `exitCode` — numeric exit status as a string.

**Ops:** `stdout`/`stderr` → `equals`/`notEquals`/`contains`/`matches`; `exitCode`
→ those plus `greaterThan`/`lessThan`. No new op vocabulary.

**Parser rules:**
- `exec` step: require exactly one of `command`/`argv`; else `PlanError`.
- An assert whose property is `stdout`/`stderr`/`exitCode` is **target-less-exempt**
  (extend the existing `clipboard` exemption). Those properties on a **non-exec**
  step still require a target (they only make sense on an `exec` step).

**Worked examples:**
```jsonc
// trigger medit's reload banner (external file-change) — pure setup, always passes:
{ "id": "touch-file", "action": "exec", "level": "integrationSuite",
  "args": { "command": "echo 'changed on disk' > /tmp/medit-ap/reload.md" } }

// verify Save wrote the right bytes:
{ "id": "verify-save", "action": "exec", "level": "happyPath",
  "args": { "argv": ["/bin/cat", "/tmp/medit-ap/doc.txt"] },
  "assert": { "property": "stdout", "op": "contains", "expected": "the saved line" } }
```

## 3. Execution, error handling, data flow

**Process execution (macOS driver `runProcess`):**
- `command` → `/bin/sh -c "<command>"`; `argv` → `argv[0]` executable, rest args.
- stdout + stderr captured via separate `Pipe`s, **read fully** so a chatty command
  can't deadlock on a full pipe buffer.
- Runs in its **own process group**; on timeout the whole group is killed (no
  orphaned children).
- **Working directory = the plan file's base directory** (same base includes resolve
  against), so relative paths behave predictably. Environment inherited.

**Timeout:** bounded by step/plan `timeoutMs`. On expiry: kill the group, step
**fails** with `exec: command exceeded timeout (Nms): <command|argv[0]>`.

**Error taxonomy (all surfaced, never swallowed):**
- **Launch failure** (bad `argv[0]`, not executable): step **fails**, `PlanError`
  naming the program + OS error. Distinct from "ran and exited nonzero."
- **Ran, nonzero exit, no assert:** step **passes** (setup-lever). A nonzero exit is
  not a launch failure — the command ran; only an assert decides.
- **Ran, assert attached:** evaluate against `stdout`/`stderr`/`exitCode`; pass iff
  assert passes; failure detail carries expected/actual.
- **Timeout:** step fails (above).
- **`exec` on a non-macOS driver:** default `runProcess` throws "exec unsupported on
  this platform" → step fails loudly (never a silent skip).

**Observability:** on a failing `exec` assert, the failure detail includes the exit
code and a **bounded** snippet of stdout/stderr (truncated to first/last N chars) so
the cause is visible without dumping megabytes. A bare passing setup `exec` stays
quiet (one pass line), but its exit code is recorded in the step result.

**Data flow:** `PlanRunner.runExec(step)` → `driver.runProcess(...)` → `ProcessResult`
→ if `step.assert != nil`, route `stdout`/`stderr`/`exitCode` through the existing
`AssertionEngine.evaluate` → `StepResult`. The same `RunObserver` hooks fire.

**Non-goals (YAGNI):** no streaming, no stdin, no per-step env/cwd overrides beyond
the plan-dir default, no background/async exec. Additive later if a real need arises.

## 4. Testing & distribution

**Pure core tests (CI gate, no `Process`):**
- `PlanParser`: `exec` requires exactly one of `command`/`argv` (reject both / reject
  neither); `stdout`/`stderr`/`exitCode` asserts on an `exec` step are target-less-
  exempt; those properties on a non-exec step still require a target.
- `AssertionEngine`: evaluating `stdout`/`stderr` (text ops) + `exitCode` (numeric
  ops) against a synthetic `ProcessResult`.
- `PlanRunner` with a `FakeDriver` whose `runProcess` returns canned results: bare
  exec passes on nonzero exit; exec+assert fails when the assert fails; a thrown
  launch-failure fails the step; the observer fires.

**macOS driver tests (real `Process`, hermetic — no GUI, run anywhere):**
- `runProcess` with `command` (`echo hi` → "hi", exit 0), with `argv` (`/bin/echo`),
  nonzero exit (`sh -c 'exit 3'` → exitCode 3), launch failure (`/nonexistent` →
  throws), and **timeout** (`sleep 10` @ `timeoutMs 200` → fails fast + killed).

**One live end-to-end** (skip-when-headless, like existing integration tests): a plan
that `exec`-writes a temp file then `exec`-`cat`s it and asserts stdout contains the
content — proves the full parse→run→assert path against the real driver.

**Distribution:** none — `exec` is a plan-level capability in the existing `autopilot`
binary + MCP server. No new CLI subcommand, no formula change, no tap bump. Ships
whenever `feature/ap-feedback` releases (behind "go").

**Docs:** AUTHORING.md — `exec` in the §4 action table + a subsection with the two
worked examples and the semantics (bare = always-pass setup; assert = gate on
stdout/stderr/exitCode); §17 note that a hung command fails on `timeoutMs`. The
response doc records the reload-banner + save-verification (+ find-in-all-tabs/print
setup) gaps as closed by `exec`.

## Constraints carried into implementation

- Core stays platform-pure (no `Process` in core; execution only in the macOS driver).
- `runProcess` has a defaulted protocol impl so no existing conformer breaks.
- Git author always `jschwefel@coldboreballisticsllc.com`.
- Hard release gate: no tag / release / tap / brew until explicit "go".
- The macos `Package.swift` local `../autopilot-core` path override stays; restore
  `Package.resolved` clean before each commit.
- NEVER touch medit's tree.
