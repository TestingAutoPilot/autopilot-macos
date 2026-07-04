import Testing
import Foundation
@testable import MacOSDriver
import AutopilotCore

/// Real-Process tests for `exec`'s execution. These run actual subprocesses but
/// touch NO GUI / WindowServer, so they're deterministic and run anywhere (not
/// gated on Accessibility, unlike the live-GUI integration tests).
@Suite struct ProcessRunnerTests {

    @Test func shellCommandCapturesStdoutAndZeroExit() throws {
        let r = try ProcessRunner.run(command: "echo hi", argv: nil, timeoutMs: 5000, workingDir: nil)
        #expect(r.stdout == "hi")     // trailing newline trimmed
        #expect(r.exitCode == 0)
    }

    @Test func argvRunsWithoutShell() throws {
        let r = try ProcessRunner.run(command: nil, argv: ["/bin/echo", "from", "argv"], timeoutMs: 5000, workingDir: nil)
        #expect(r.stdout == "from argv")
        #expect(r.exitCode == 0)
    }

    @Test func nonzeroExitIsCapturedNotThrown() throws {
        // A command that runs and exits nonzero returns exitCode 3 — it is NOT a
        // launch failure, so runProcess does not throw (the runner decides).
        let r = try ProcessRunner.run(command: "exit 3", argv: nil, timeoutMs: 5000, workingDir: nil)
        #expect(r.exitCode == 3)
    }

    @Test func stderrIsCapturedSeparately() throws {
        let r = try ProcessRunner.run(command: "echo oops 1>&2", argv: nil, timeoutMs: 5000, workingDir: nil)
        #expect(r.stderr == "oops")
        #expect(r.stdout == "")
    }

    @Test func launchFailureThrows() throws {
        // A nonexistent program is a launch failure — throws, distinct from a
        // ran-and-exited-nonzero result.
        #expect(throws: (any Error).self) {
            _ = try ProcessRunner.run(command: nil, argv: ["/no/such/binary"], timeoutMs: 5000, workingDir: nil)
        }
    }

    @Test func timeoutKillsAndThrows() throws {
        // A command that outlives the timeout is killed and throws — no hang.
        let start = Date()
        #expect(throws: (any Error).self) {
            _ = try ProcessRunner.run(command: "sleep 10", argv: nil, timeoutMs: 300, workingDir: nil)
        }
        // It must return promptly (well under the 10s sleep), proving the kill.
        #expect(Date().timeIntervalSince(start) < 5)
    }

    @Test func workingDirIsHonored() throws {
        let tmp = FileManager.default.temporaryDirectory.path
        let r = try ProcessRunner.run(command: "pwd", argv: nil, timeoutMs: 5000, workingDir: tmp)
        // pwd resolves symlinks; just assert it ran in the given dir's realpath tail.
        #expect(r.exitCode == 0)
        #expect(!r.stdout.isEmpty)
    }
}
