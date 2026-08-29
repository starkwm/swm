import CoreGraphics
import Testing

@testable import SwmLib

@Suite("DwindleLayout")
struct DwindleLayoutTests {
  @Test("layout: returns no frames for no windows")
  func layoutReturnsNoFramesForNoWindows() {
    #expect(
      DwindleLayout().layout(
        tree: tilingTree([]),
        in: CGRect(x: 0, y: 0, width: 100, height: 100),
        settings: .defaults
      ) == .frames([:])
    )
  }

  @Test("layout: fills padded bounds for one window")
  func layoutFillsPaddedBoundsForOneWindow() {
    var settings = SpaceSettings.defaults
    settings.padding = SpacePadding(top: 10, bottom: 20, left: 30, right: 40)

    let result = DwindleLayout().layout(
      tree: tilingTree([1]),
      in: CGRect(x: -300, y: 24, width: 300, height: 200),
      settings: settings
    )

    #expect(result == .frames([1: CGRect(x: -270, y: 34, width: 230, height: 170)]))
  }

  @Test("layout: recursively bisects the longest remaining edge")
  func layoutRecursivelyBisectsLongestRemainingEdge() {
    var settings = SpaceSettings.defaults
    settings.gap = 10

    let result = DwindleLayout().layout(
      tree: tilingTree([1, 2, 3, 4]),
      in: CGRect(x: 0, y: 0, width: 1_000, height: 800),
      settings: settings
    )

    #expect(
      result
        == .frames([
          1: CGRect(x: 0, y: 0, width: 495, height: 800),
          2: CGRect(x: 505, y: 0, width: 495, height: 395),
          3: CGRect(x: 505, y: 405, width: 243, height: 395),
          4: CGRect(x: 758, y: 405, width: 242, height: 395),
        ])
    )
  }

  @Test("layout: chooses the longest edge for portrait bounds")
  func layoutChoosesLongestEdgeForPortraitBounds() {
    let result = DwindleLayout().layout(
      tree: tilingTree([1, 2, 3]),
      in: CGRect(x: -200, y: 20, width: 400, height: 800),
      settings: .defaults
    )

    #expect(
      result
        == .frames([
          1: CGRect(x: -200, y: 20, width: 400, height: 400),
          2: CGRect(x: -200, y: 420, width: 200, height: 400),
          3: CGRect(x: 0, y: 420, width: 200, height: 400),
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
        CGRect(x: 0, y: 0, width: 1, height: 1.5),
        [CGWindowID(1), 2],
        TilingLayoutConstraint.tileHeight
      ),
      (
        CGRect(x: 0, y: 0, width: 1.5, height: 1),
        [CGWindowID(1), 2],
        TilingLayoutConstraint.tileWidth
      ),
    ]
  )
  func layoutReportsMinimumSizeConstraint(
    bounds: CGRect,
    windowIDs: [CGWindowID],
    constraint: TilingLayoutConstraint
  ) {
    let result = DwindleLayout().layout(
      tree: tilingTree(windowIDs),
      in: bounds,
      settings: .defaults
    )

    #expect(result == .insufficientSpace(constraint))
  }

  @Test("layout: reports gaps that consume the remaining split")
  func layoutReportsGapsThatConsumeTheRemainingSplit() {
    var settings = SpaceSettings.defaults
    settings.gap = 400
    let layout = DwindleLayout()

    #expect(
      layout.layout(
        tree: tilingTree([1, 2]),
        in: CGRect(x: 0, y: 0, width: 300, height: 150),
        settings: settings
      ) == .insufficientSpace(.horizontalGap)
    )
    #expect(
      layout.layout(
        tree: tilingTree([1, 2]),
        in: CGRect(x: 0, y: 0, width: 150, height: 300),
        settings: settings
      ) == .insufficientSpace(.verticalGap)
    )
  }

  @Test("layout: rejects zero-width tiles with default constraints")
  func layoutRejectsZeroWidthTilesWithDefaultConstraints() {
    var settings = SpaceSettings.defaults
    settings.gap = 100

    let result = DwindleLayout().layout(
      windowIDs: [1, 2],
      in: CGRect(x: 0, y: 0, width: 100, height: 100),
      settings: settings
    )

    #expect(result == .insufficientSpace(.tileWidth))
  }

  @Test("layout: is idempotent")
  func layoutIsIdempotent() {
    var settings = SpaceSettings.defaults
    settings.padding = SpacePadding(top: 7, bottom: 11, left: 13, right: 17)
    settings.gap = 9
    let layout = DwindleLayout()
    let bounds = CGRect(x: -1_024, y: -20, width: 1_024, height: 768)

    let tree = tilingTree([1, 2, 3, 4])
    let first = layout.layout(tree: tree, in: bounds, settings: settings)
    let second = layout.layout(tree: tree, in: bounds, settings: settings)

    #expect(first == second)
  }
}
