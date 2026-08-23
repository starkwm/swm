import CoreGraphics
import Testing

@testable import SwmLib

@Suite("MasterStackLayoutEngine")
struct MasterStackLayoutEngineTests {
  @Test("layout: returns no frames for no windows")
  func layoutReturnsNoFramesForNoWindows() {
    #expect(
      MasterStackLayoutEngine().layout(
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

    let result = MasterStackLayoutEngine().layout(
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

    let result = MasterStackLayoutEngine().layout(
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
    let engine = MasterStackLayoutEngine()
    let bounds = CGRect(x: 0, y: 0, width: 1_000, height: 500)

    #expect(
      engine.layout(windowIDs: [1, 2], in: bounds, settings: .defaults, masterRatio: 0)
        == .frames([
          1: CGRect(x: 0, y: 0, width: 100, height: 500),
          2: CGRect(x: 100, y: 0, width: 900, height: 500),
        ])
    )
    #expect(
      engine.layout(windowIDs: [1, 2], in: bounds, settings: .defaults, masterRatio: 1)
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
    let result = MasterStackLayoutEngine().layout(
      windowIDs: windowIDs,
      in: bounds,
      settings: .defaults
    )

    #expect(result == .insufficientSpace(constraint))
  }

  @Test("layout: is idempotent")
  func layoutIsIdempotent() {
    var settings = SpaceSettings.defaults
    settings.padding = SpacePadding(top: 7, bottom: 11, left: 13, right: 17)
    settings.gap = 9
    let engine = MasterStackLayoutEngine()
    let bounds = CGRect(x: -1_024, y: -20, width: 1_024, height: 768)

    let first = engine.layout(windowIDs: [1, 2, 3], in: bounds, settings: settings)
    let second = engine.layout(windowIDs: [1, 2, 3], in: bounds, settings: settings)

    #expect(first == second)
  }
}
