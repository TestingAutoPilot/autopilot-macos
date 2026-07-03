import Testing
import Foundation
@testable import AutopilotCockpit
import AutopilotCore

@Suite struct PlanDocumentTests {
    private func writeTemp(_ json: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("cockpit-plan-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("plan.json")
        try json.data(using: .utf8)!.write(to: url)
        return url
    }

    @Test func loadsValidPlan() throws {
        let url = try writeTemp("""
        {"schemaVersion":"1.1","name":"demo",
         "target":{"bundleId":"com.example"},
         "steps":[{"id":"s1","action":"launch","level":"happyPath"}]}
        """)
        let result = PlanDocument.load(url: url)
        switch result {
        case .success(let loaded):
            #expect(loaded.plan.name == "demo")
            #expect(loaded.plan.steps.count == 1)
        case .failure(let msg):
            Issue.record("expected success, got \(msg)")
        }
    }

    @Test func reportsParseErrorAsFailure() throws {
        let url = try writeTemp(#"{"not":"a plan"}"#)
        let result = PlanDocument.load(url: url)
        if case .success = result { Issue.record("expected failure for malformed plan") }
    }
}
