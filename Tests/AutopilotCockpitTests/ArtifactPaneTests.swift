import Testing
import Foundation
@testable import AutopilotCockpit

@Suite struct ArtifactPaneTests {
    @Test func nilPathsYieldNil() {
        #expect(ArtifactLoader.image(atPath: nil) == nil)
        #expect(ArtifactLoader.axDumpText(atPath: nil) == nil)
    }

    @Test func missingFileYieldsNil() {
        #expect(ArtifactLoader.image(atPath: "/no/such/file.png") == nil)
        #expect(ArtifactLoader.axDumpText(atPath: "/no/such/file.json") == nil)
    }

    @Test func readsAxDumpText() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dump-\(UUID().uuidString).json")
        try #"{"nodes":[]}"#.data(using: .utf8)!.write(to: url)
        #expect(ArtifactLoader.axDumpText(atPath: url.path)?.contains("nodes") == true)
    }
}
