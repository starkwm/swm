import CoreGraphics
import Testing

@testable import SwmLib

@Suite("MasterLayout")
struct MasterLayoutTests {
  @Test("layout: returns no frames for no windows")
  func layoutReturnsNoFramesForNoWindows() {
    #expect(
      MasterLayout().layout(
        windowIDs: [],
        in: CGRect(x: 0, y: 0, width: 100, height: 100),
        settings: .defaults
      ) == .frames([:])
    )
  }

  @Test("layout: fills padded bounds for one window")
  func layoutFillsPaddedBoundsForOneWindow() {
    var settings = SpaceSettings.defaults
    settings.padding = SpacePadding(top: 10, bottom: 20, left: 30, right: 40)

    let result = MasterLayout().layout(
      windowIDs: [1],
      in: CGRect(x: -300, y: 24, width: 300, height: 200),
      settings: settings
    )

    #expect(result == .frames([1: CGRect(x: -270, y: 34, width: 230, height: 170)]))
  }

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

  @Test("layout: places a right master after its stack")
  func layoutPlacesRightMasterAfterStack() {
    let result = MasterLayout().layout(
      windowIDs: [1, 2, 3],
      in: CGRect(x: 0, y: 0, width: 1_000, height: 800),
      settings: .defaults,
      masterRatio: 0.6,
      placement: .right
    )

    #expect(
      result
        == .frames([
          1: CGRect(x: 400, y: 0, width: 600, height: 800),
          2: CGRect(x: 0, y: 0, width: 400, height: 400),
          3: CGRect(x: 0, y: 400, width: 400, height: 400),
        ])
    )
  }

  @Test("layout: places a top master above a horizontal stack")
  func layoutPlacesTopMasterAboveStack() {
    let result = MasterLayout().layout(
      windowIDs: [1, 2, 3],
      in: CGRect(x: 0, y: 0, width: 1_000, height: 800),
      settings: .defaults,
      masterRatio: 0.6,
      placement: .top
    )

    #expect(
      result
        == .frames([
          1: CGRect(x: 0, y: 0, width: 1_000, height: 480),
          2: CGRect(x: 0, y: 480, width: 500, height: 320),
          3: CGRect(x: 500, y: 480, width: 500, height: 320),
        ])
    )
  }

  @Test("layout: places a bottom master below a horizontal stack")
  func layoutPlacesBottomMasterBelowStack() {
    let result = MasterLayout().layout(
      windowIDs: [1, 2, 3],
      in: CGRect(x: 0, y: 0, width: 1_000, height: 800),
      settings: .defaults,
      masterRatio: 0.6,
      placement: .bottom
    )

    #expect(
      result
        == .frames([
          1: CGRect(x: 0, y: 320, width: 1_000, height: 480),
          2: CGRect(x: 0, y: 0, width: 500, height: 320),
          3: CGRect(x: 500, y: 0, width: 500, height: 320),
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

  @Test("layout: is idempotent")
  func layoutIsIdempotent() {
    var settings = SpaceSettings.defaults
    settings.padding = SpacePadding(top: 7, bottom: 11, left: 13, right: 17)
    settings.gap = 9
    let layout = MasterLayout()
    let bounds = CGRect(x: -1_024, y: -20, width: 1_024, height: 768)

    let first = layout.layout(windowIDs: [1, 2, 3], in: bounds, settings: settings)
    let second = layout.layout(windowIDs: [1, 2, 3], in: bounds, settings: settings)

    #expect(first == second)
  }
}
