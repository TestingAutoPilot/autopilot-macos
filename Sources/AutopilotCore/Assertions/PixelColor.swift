import Foundation
import CoreGraphics
import AppKit

/// Deterministic pixel-color sampling and comparison, so visual features that
/// the Accessibility API cannot see (syntax colors, rainbow brackets, gutters)
/// can still be asserted. No LLM — a fixed Euclidean-distance threshold in RGB.
public enum PixelColor {
    public struct RGB: Equatable {
        public var r: Int; public var g: Int; public var b: Int   // 0...255
        public init(r: Int, g: Int, b: Int) { self.r = r; self.g = g; self.b = b }
    }

    /// Parse "#RRGGBB" or "RRGGBB" (case-insensitive) into RGB, or nil.
    public static func parseHex(_ hex: String) -> RGB? {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = Int(s, radix: 16) else { return nil }
        return RGB(r: (v >> 16) & 0xFF, g: (v >> 8) & 0xFF, b: v & 0xFF)
    }

    /// Euclidean distance in RGB space (0 = identical, ~441 = black↔white).
    public static func distance(_ a: RGB, _ b: RGB) -> Double {
        let dr = Double(a.r - b.r), dg = Double(a.g - b.g), db = Double(a.b - b.b)
        return (dr * dr + dg * dg + db * db).squareRoot()
    }

    /// Does `actual` match `expected` within `tolerance` (RGB distance)?
    public static func matches(_ actual: RGB, _ expected: RGB, tolerance: Double) -> Bool {
        distance(actual, expected) <= tolerance
    }

    /// Read the color of a single screen pixel at `point` (screen coordinates),
    /// or nil if the capture failed. Captures a 1×1 region for efficiency.
    public static func sample(at point: CGPoint) -> RGB? {
        let rect = CGRect(x: point.x, y: point.y, width: 1, height: 1)
        guard let image = CGWindowListCreateImage(rect, .optionAll, kCGNullWindowID, []),
              let data = image.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else { return nil }
        // CGWindowListCreateImage is BGRA on macOS.
        let b = Int(ptr[0]); let g = Int(ptr[1]); let r = Int(ptr[2])
        return RGB(r: r, g: g, b: b)
    }
}
