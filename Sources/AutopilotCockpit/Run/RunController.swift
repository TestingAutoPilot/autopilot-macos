import Foundation
import Observation
import AutopilotCore

/// UI-facing state of one step during a run.
enum StepUIState: Equatable {
    case pending, running, pass, fail, error, skipped
    init(_ outcome: StepOutcome) {
        switch outcome {
        case .pass: self = .pass
        case .fail: self = .fail
        case .error: self = .error
        case .skipped: self = .skipped
        }
    }
    var symbol: String {
        switch self {
        case .pending: return "circle"
        case .running: return "play.circle.fill"
        case .pass: return "checkmark.circle.fill"
        case .fail: return "xmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .skipped: return "minus.circle"
        }
    }
}

struct StepRow: Identifiable, Equatable {
    let id: String
    var state: StepUIState
    var durationMs: Int?
    var message: String?
    var screenshot: String?
    var axDump: String?
}

/// Bridges PlanRunner's RunObserver callbacks to observable UI rows. Runs the
/// (synchronous, blocking) PlanRunner on a background Task and marshals every
/// observer callback back onto the main actor before mutating state.
@MainActor
@Observable
final class RunController: RunObserver {
    private(set) var rows: [StepRow] = []
    private(set) var report: Report?
    private(set) var isRunning = false
    private(set) var runError: String?

    private var indexOfId: [String: Int] = [:]

    func run(_ loaded: LoadedPlan, driver: any AppDriver,
             maxLevel: StepLevel?, keepGoing: Bool, demoMode: Bool = false) {
        // Seed rows from the plan's steps, all pending.
        rows = loaded.plan.steps.map { StepRow(id: $0.id, state: .pending, durationMs: nil, message: nil) }
        indexOfId = Dictionary(uniqueKeysWithValues: rows.enumerated().map { ($1.id, $0) })
        report = nil; runError = nil; isRunning = true

        let artifacts = FileManager.default.temporaryDirectory
            .appendingPathComponent("cockpit-run-\(UUID().uuidString)")
        let options = RunOptions(keepGoing: keepGoing, artifactsDir: artifacts,
                                 planBaseDir: loaded.baseDir, maxLevel: maxLevel,
                                 observer: self, demoMode: demoMode)
        let plan = loaded.plan
        // PlanRunner.run is blocking; run it off the main actor. Bind self to a
        // local so the detached closure captures an immutable reference (Swift 6
        // rejects capturing the mutable `self` var across the concurrency boundary).
        let controller = self
        Task.detached {
            do {
                _ = try PlanRunner(driver: driver).run(plan, options: options)
            } catch {
                await controller.finishWithError("\(error)")
            }
        }
    }

    private func finishWithError(_ msg: String) {
        runError = msg; isRunning = false
    }

    // MARK: RunObserver (called from the background run; hop to main).

    nonisolated func stepWillStart(_ step: Step, index: Int, of total: Int) {
        let id = step.id
        Task { @MainActor in
            if let i = self.indexOfId[id] { self.rows[i].state = .running }
        }
    }

    nonisolated func stepDidFinish(_ result: StepResult, index: Int) {
        let id = result.id
        let state = StepUIState(result.result)
        let dur = result.durationMs
        let msg = result.message
        let shot = result.screenshot
        let dump = result.axDump
        Task { @MainActor in
            if let i = self.indexOfId[id] {
                self.rows[i].state = state
                self.rows[i].durationMs = dur
                self.rows[i].message = msg
                self.rows[i].screenshot = shot
                self.rows[i].axDump = dump
            }
        }
    }

    nonisolated func runDidFinish(_ report: Report) {
        Task { @MainActor in
            self.report = report
            self.isRunning = false
        }
    }
}
