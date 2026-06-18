import Testing
import Foundation
@testable import AutopilotCore

@Suite struct PixelColorTests {
    @Test func parsesHexWithAndWithoutHash() {
        #expect(PixelColor.parseHex("#FF8800") == PixelColor.RGB(r: 255, g: 136, b: 0))
        #expect(PixelColor.parseHex("ff8800") == PixelColor.RGB(r: 255, g: 136, b: 0))
    }

    @Test func rejectsBadHex() {
        #expect(PixelColor.parseHex("#FFF") == nil)
        #expect(PixelColor.parseHex("nothex") == nil)
    }

    @Test func distanceZeroForIdentical() {
        let c = PixelColor.RGB(r: 10, g: 20, b: 30)
        #expect(PixelColor.distance(c, c) == 0)
    }

    @Test func matchesWithinTolerance() {
        let gold = PixelColor.RGB(r: 255, g: 200, b: 0)
        let nearGold = PixelColor.RGB(r: 250, g: 198, b: 3)
        #expect(PixelColor.matches(nearGold, gold, tolerance: 12))
        #expect(!PixelColor.matches(PixelColor.RGB(r: 0, g: 0, b: 255), gold, tolerance: 12))
    }
}
