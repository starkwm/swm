import CoreGraphics
import Testing

@testable import SwmLib

@Suite("Screen geometry")
struct ScreenGeometryTests {
  @Test(
    "uses the primary screen origin for every display",
    arguments: [
      (CGRect(x: 0, y: 0, width: 1440, height: 900), CGRect(x: 0, y: 0, width: 1440, height: 900)),
      (
        CGRect(x: 0, y: 900, width: 1920, height: 1080),
        CGRect(x: 0, y: -1080, width: 1920, height: 1080)
      ),
      (
        CGRect(x: 200, y: -1080, width: 1920, height: 1080),
        CGRect(x: 200, y: 900, width: 1920, height: 1080)
      ),
      (
        CGRect(x: -1920, y: -180, width: 1920, height: 1080),
        CGRect(x: -1920, y: 0, width: 1920, height: 1080)
      ),
      (
        CGRect(x: 1440, y: -180, width: 1920, height: 1080),
        CGRect(x: 1440, y: 0, width: 1920, height: 1080)
      ),
    ]
  )
  func displayPositions(frame: CGRect, expected: CGRect) {
    let primary = CGRect(x: 0, y: 0, width: 1440, height: 900)
    #expect(ScreenGeometry.accessibilityFrame(frame, primaryFrame: primary) == expected)
    // A 24-point menu bar, 60-point bottom Dock, and 8-point left inset.
    let visible = CGRect(
      x: frame.minX + 8,
      y: frame.minY + 60,
      width: frame.width - 8,
      height: frame.height - 84
    )
    let expectedVisible = CGRect(
      x: expected.minX + 8,
      y: expected.minY + 24,
      width: expected.width - 8,
      height: expected.height - 84
    )
    #expect(ScreenGeometry.accessibilityFrame(visible, primaryFrame: primary) == expectedVisible)
  }
}
