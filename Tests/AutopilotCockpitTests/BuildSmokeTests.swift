import Testing
@testable import AutopilotCockpit

@Suite struct BuildSmokeTests {
    @Test func modesAreThree() {
        #expect(CockpitMode.allCases.count == 3)
        #expect(CockpitMode.allCases.map(\.rawValue) == ["inspect", "author", "run"])
    }
}
