import CoreGraphics
import Testing

@testable import SwmLib

@Suite("MasterLayout")
struct MasterLayoutTests {
  @Test("layout: distributes odd dimensions and gaps without drift")
  func layoutDistributesOddDimensionsAndGapsWithoutDrift() {
    var settings = SpaceSettings.defaults
    settings.gap = 5

    let result = MasterLayout().layout(
      windowIDs: [1, 2, 3, 4],
      in: CGRect(x: -301, y: 25, width: 301, height: 202),
      settings: settings
    )

    #expect(
      result
        == .frames([
          1: CGRect(x: -301, y: 25, width: 148, height: 202),
          2: CGRect(x: -148, y: 25, width: 148, height: 64),
          3: CGRect(x: -148, y: 94, width: 148, height: 64),
          4: CGRect(x: -148, y: 163, width: 148, height: 64),
        ])
    )
  }

  @Test("layout: clamps ratios before calculating frames")
  func layoutClampsRatiosBeforeCalculatingFrames() {
    let layout = MasterLayout()
    let bounds = CGRect(x: 0, y: 0, width: 1_000, height: 500)

    #expect(
      layout.layout(windowIDs: [1, 2], in: bounds, settings: .defaults, masterRatio: 0)
        == .frames([
          1: CGRect(x: 0, y: 0, width: 100, height: 500),
          2: CGRect(x: 100, y: 0, width: 900, height: 500),
        ])
    )
    #expect(
      layout.layout(windowIDs: [1, 2], in: bounds, settings: .defaults, masterRatio: 1)
        == .frames([
          1: CGRect(x: 0, y: 0, width: 900, height: 500),
          2: CGRect(x: 900, y: 0, width: 100, height: 500),
        ])
    )
  }

  @Test(
    "layout: reports minimum-size constraint",
    arguments: [
      (
        CGRect(x: 0, y: 0, width: 0, height: 1),
        [CGWindowID(1)],
        TilingLayoutConstraint.usableBounds
      ),
      (
        CGRect(x: 0, y: 0, width: 1, height: 1),
        [CGWindowID(1), 2],
        TilingLayoutConstraint.stackWidth
      ),
      (
        CGRect(x: 0, y: 0, width: 2, height: 1),
        [CGWindowID(1), 2, 3],
        TilingLayoutConstraint.stackHeight
      ),
    ]
  )
  func layoutReportsMinimumSizeConstraint(
    bounds: CGRect,
    windowIDs: [CGWindowID],
    constraint: TilingLayoutConstraint
  ) {
    let result = MasterLayout().layout(
      windowIDs: windowIDs,
      in: bounds,
      settings: .defaults
    )

    #expect(result == .insufficientSpace(constraint))
  }

  @Test("layout: rejects zero-width tiles with default constraints")
  func layoutRejectsZeroWidthTilesWithDefaultConstraints() {
    var settings = SpaceSettings.defaults
    settings.gap = 100

    let result = MasterLayout().layout(
      windowIDs: [1, 2],
      in: CGRect(x: 0, y: 0, width: 100, height: 100),
      settings: settings
    )

    #expect(result == .insufficientSpace(.masterWidth))
  }
}
