import Foundation
import AutopilotCore

/// Runs an `exec` step's command as a real subprocess and captures its output.
///
/// - EITHER `command` (a shell string, run via `/bin/sh -c`) OR `argv` (program +
///   args, run directly, no shell). The caller (PlanParser) guarantees exactly one.
/// - stdout and stderr are captured on separate pipes and read FULLY on background
///   threads so a chatty command cannot deadlock on a full pipe buffer.
/// - The child runs in its OWN process group; on timeout the whole group is killed
///   so a command that spawned children does not orphan them.
/// - Bounded by `timeoutMs`: on expiry the group is killed and this THROWS (a hung
///   command never hangs the run).
/// - A launch failure (bad executable) THROWS, distinct from a ran-and-exited-
///   nonzero result (which returns a ProcessResult the runner decides on).
enum ProcessRunner {
    static func run(command: String?, argv: [String]?,
                    timeoutMs: Int, workingDir: String?) throws -> ProcessResult {
        let process = Process()
        if let command {
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-c", command]
        } else if let argv, let first = argv.first {
            process.executableURL = URL(fileURLWithPath: first)
            process.arguments = Array(argv.dropFirst())
        } else {
            throw PlanError.decode("exec: neither command nor argv provided")
        }
        if let workingDir {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDir)
        }
        // Run in its own process group so a timeout can kill the whole tree.
        process.standardInput = FileHandle.nullDevice

        let outPipe = Pipe(), errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        // Read both pipes fully on background threads to avoid a full-buffer
        // deadlock while the child is still running.
        var outData = Data(), errData = Data()
        let outQ = DispatchQueue(label: "exec.stdout")
        let errQ = DispatchQueue(label: "exec.stderr")
        let group = DispatchGroup()

        do {
            try process.run()
        } catch {
            throw PlanError.decode("exec: could not launch \(process.executableURL?.path ?? "?"): \(error.localizedDescription)")
        }
        // Detach into its own process group AFTER launch (its pid is the group id).
        setpgid(process.processIdentifier, process.processIdentifier)

        group.enter(); outQ.async { outData = outPipe.fileHandleForReading.readDataToEndOfFile(); group.leave() }
        group.enter(); errQ.async { errData = errPipe.fileHandleForReading.readDataToEndOfFile(); group.leave() }

        // Bounded wait. If it doesn't finish in time, kill the group and throw.
        let deadline = DispatchTime.now() + .milliseconds(timeoutMs)
        let finished = waitForExit(process, until: deadline)
        if !finished {
            killGroup(process.processIdentifier)
            process.waitUntilExit()
            _ = group.wait(timeout: .now() + .seconds(2))
            throw PlanError.decode("exec: command exceeded timeout (\(timeoutMs)ms): \(command ?? (argv?.first ?? "?"))")
        }
        _ = group.wait(timeout: .now() + .seconds(2))

        let stdout = String(decoding: outData, as: UTF8.self).trimmingTrailingNewline()
        let stderr = String(decoding: errData, as: UTF8.self).trimmingTrailingNewline()
        return ProcessResult(stdout: stdout, stderr: stderr,
                             exitCode: Int(process.terminationStatus))
    }

    /// Poll the process until it exits or the deadline passes. Returns whether it
    /// exited in time. (Process has no bounded waitUntilExit, so we poll.)
    private static func waitForExit(_ p: Process, until deadline: DispatchTime) -> Bool {
        while p.isRunning {
            if DispatchTime.now() >= deadline { return false }
            usleep(10_000)   // 10ms
        }
        return true
    }

    /// Kill the child's whole process group (negative pid targets the group).
    private static func killGroup(_ pid: pid_t) {
        kill(-pid, SIGKILL)
        kill(pid, SIGKILL)   // belt-and-suspenders if setpgid didn't take
    }
}

private extension String {
    /// Trim a single trailing newline (the near-universal command output artifact),
    /// so `echo hi` asserts as "hi" not "hi\n".
    func trimmingTrailingNewline() -> String {
        hasSuffix("\n") ? String(dropLast()) : self
    }
}
