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
        == [
          1: CGRect(x: -301, y: 25, width: 148, height: 202),
          2: CGRect(x: -148, y: 25, width: 148, height: 64),
          3: CGRect(x: -148, y: 94, width: 148, height: 64),
          4: CGRect(x: -148, y: 163, width: 148, height: 64),
        ]
    )
  }

  @Test("layout: clamps ratios before calculating frames")
  func layoutClampsRatiosBeforeCalculatingFrames() {
    let layout = MasterLayout()
    let bounds = CGRect(x: 0, y: 0, width: 1_000, height: 500)

    #expect(
      layout.layout(windowIDs: [1, 2], in: bounds, settings: .defaults, masterRatio: 0)
        == [
          1: CGRect(x: 0, y: 0, width: 100, height: 500),
          2: CGRect(x: 100, y: 0, width: 900, height: 500),
        ]
    )
    #expect(
      layout.layout(windowIDs: [1, 2], in: bounds, settings: .defaults, masterRatio: 1)
        == [
          1: CGRect(x: 0, y: 0, width: 900, height: 500),
          2: CGRect(x: 900, y: 0, width: 100, height: 500),
        ]
    )
  }

  @Test(
    "layout: returns no frames below the minimum size",
    arguments: [
      (
        CGRect(x: 0, y: 0, width: 0, height: 1),
        [CGWindowID(1)]
      ),
      (
        CGRect(x: 0, y: 0, width: 1, height: 1),
        [CGWindowID(1), 2]
      ),
      (
        CGRect(x: 0, y: 0, width: 2, height: 1),
        [CGWindowID(1), 2, 3]
      ),
    ]
  )
  func layoutReturnsNoFramesBelowTheMinimumSize(
    bounds: CGRect,
    windowIDs: [CGWindowID]
  ) {
    let result = MasterLayout().layout(
      windowIDs: windowIDs,
      in: bounds,
      settings: .defaults
    )

    #expect(result == nil)
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

    #expect(result == nil)
  }

  @Test("layout: places the master pane on each edge")
  func layoutPlacesTheMasterPaneOnEachEdge() {
    let layout = MasterLayout()
    let wide = CGRect(x: 0, y: 0, width: 1_000, height: 500)
    let tall = CGRect(x: 0, y: 0, width: 500, height: 1_000)

    #expect(
      layout.layout(windowIDs: [1, 2], in: wide, settings: .defaults, placement: .right)
        == [
          1: CGRect(x: 500, y: 0, width: 500, height: 500),
          2: CGRect(x: 0, y: 0, width: 500, height: 500),
        ]
    )
    #expect(
      layout.layout(windowIDs: [1, 2, 3], in: tall, settings: .defaults, placement: .top)
        == [
          1: CGRect(x: 0, y: 0, width: 500, height: 500),
          2: CGRect(x: 0, y: 500, width: 250, height: 500),
          3: CGRect(x: 250, y: 500, width: 250, height: 500),
        ]
    )
    #expect(
      layout.layout(windowIDs: [1, 2, 3], in: tall, settings: .defaults, placement: .bottom)
        == [
          1: CGRect(x: 0, y: 500, width: 500, height: 500),
          2: CGRect(x: 0, y: 0, width: 250, height: 500),
          3: CGRect(x: 250, y: 0, width: 250, height: 500),
        ]
    )
  }

  @Test(
    "layout: returns no frames for undersized top and bottom placements",
    arguments: [
      (CGRect(x: 0, y: 0, width: 100, height: 50), 100, 2),
      (CGRect(x: 0, y: 0, width: 100, height: 100), 100, 2),
      (CGRect(x: 0, y: 0, width: 1, height: 1), 0, 2),
      (CGRect(x: 0, y: 0, width: 1, height: 2), 0, 3),
    ]
  )
  func layoutReturnsNoFramesForUndersizedRows(
    bounds: CGRect,
    gap: Int,
    windowCount: Int
  ) {
    var settings = SpaceSettings.defaults
    settings.gap = gap
    let windowIDs = (1...windowCount).map { CGWindowID($0) }

    for placement in [MasterPlacement.top, .bottom] {
      let result = MasterLayout().layout(
        windowIDs: windowIDs,
        in: bounds,
        settings: settings,
        placement: placement
      )
      #expect(result == nil)
    }
  }
}
