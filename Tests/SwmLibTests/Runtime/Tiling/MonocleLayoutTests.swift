import CoreGraphics
import Testing

@testable import SwmLib

@Suite("MonocleLayout")
struct MonocleLayoutTests {
  @Test("layout: returns no frames for no windows")
  func layoutReturnsNoFramesForNoWindows() {
    #expect(
      MonocleLayout().layout(
        windowIDs: [],
        in: CGRect(x: 0, y: 0, width: 100, height: 100),
        settings: .defaults
      ) == .frames([:])
    )
  }

  @Test("layout: fills padded bounds for every window")
  func layoutFillsPaddedBoundsForEveryWindow() {
    var settings = SpaceSettings.defaults
    settings.padding = SpacePadding(top: 10, bottom: 20, left: 30, right: 40)
    settings.gap = 50

    let result = MonocleLayout().layout(
      windowIDs: [1, 2, 3],
      in: CGRect(x: -300, y: 24, width: 300, height: 200),
      settings: settings
    )

    let expectedFrame = CGRect(x: -270, y: 34, width: 230, height: 170)
    #expect(
      result
        == .frames([
          1: expectedFrame,
          2: expectedFrame,
          3: expectedFrame,
        ])
    )
  }

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
