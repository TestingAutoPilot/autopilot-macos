import Foundation
import AutopilotCore

/// A parsed plan plus its origin directory and lint findings, ready for the UI.
struct LoadedPlan {
    let plan: Plan
    let baseDir: URL
    let findings: [String]   // human-readable lint lines (may be empty)
}

/// A load/parse failure carrying a human-readable message. (Result's failure
/// type must be an Error; a bare String isn't one.)
struct PlanLoadError: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}

/// Loads a plan file from disk: parse (with include resolution) + lint. Pure I/O
/// wrapper over PlanParser/PlanLinter; surfaces parse errors as a failure.
enum PlanDocument {
    static func load(url: URL) -> Result<LoadedPlan, PlanLoadError> {
        let baseDir = url.deletingLastPathComponent()
        do {
            let data = try Data(contentsOf: url)
            let plan = try PlanParser().parse(data: data, baseDirectory: baseDir)
            let findings = PlanLinter().lint(plan).map { formatted($0) }
            return .success(LoadedPlan(plan: plan, baseDir: baseDir, findings: findings))
        } catch {
            return .failure(PlanLoadError(message: "\(error)"))
        }
    }

    /// One lint finding as a display line, e.g. "error: menu needs args.menuPath [s3]".
    private static func formatted(_ f: PlanLinter.Finding) -> String {
        let location = f.stepId.map { " [\($0)]" } ?? ""
        return "\(f.severity.rawValue): \(f.message)\(location)"
    }
}
