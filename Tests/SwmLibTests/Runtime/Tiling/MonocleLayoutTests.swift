import CoreGraphics
import Testing

@testable import SwmLib

@Suite("MonocleLayout")
struct MonocleLayoutTests {
  @Test("layout: reports minimum-size constraint")
  func layoutReportsMinimumSizeConstraint() {
    let result = MonocleLayout().layout(
      windowIDs: [1, 2],
      in: CGRect(x: 0, y: 0, width: 0, height: 100),
      settings: .defaults
    )

    #expect(result == .insufficientSpace(.usableBounds))
  }
}
