import CoreGraphics
import Testing

@testable import SwmLib

@Suite("WindowGrid")
struct WindowGridTests {
  @Test("frame: neighboring rows and columns share cells, gaps, and span boundaries")
  func frameNeighboringRowsAndColumnsShareCellsGapsAndSpanBoundaries() throws {
    let bounds = CGRect(x: -30, y: 10, width: 300, height: 300)
    let settings = SpaceSettings(padding: .zero, gap: 15)
    for index in 0..<3 {
      let column = try #require(WindowGrid(argument: "3:1:\(index):0:1:1"))
      let row = try #require(WindowGrid(argument: "1:3:0:\(index):1:1"))
      expect(
        column.frame(in: bounds, settings: settings),
        equals: CGRect(x: -30 + index * 105, y: 10, width: 90, height: 300)
      )
      expect(
        row.frame(in: bounds, settings: settings),
        equals: CGRect(x: -30, y: 10 + index * 105, width: 300, height: 90)
      )
    }
    let span = try #require(WindowGrid(argument: "3:3:0:0:2:2"))
    expect(
      span.frame(in: bounds, settings: settings),
      equals: CGRect(x: -30, y: 10, width: 195, height: 195)
    )
  }

  @Test("init: clamps position and size")
  func initClampsPositionAndSize() throws {
    let grid = try #require(
      WindowGrid(rows: 2, columns: 3, x: 99, y: 99, width: 99, height: 0)
    )

    expect(
      grid.frame(in: CGRect(x: 0, y: 0, width: 300, height: 120), settings: .defaults),
      equals: CGRect(x: 200, y: 60, width: 100, height: 60)
    )
  }

  @Test("frame: places window in left two thirds")
  func framePlacesWindowInLeftTwoThirds() throws {
    let grid = try #require(
      WindowGrid(rows: 1, columns: 3, x: 0, y: 0, width: 2, height: 1)
    )

    expect(
      grid.frame(in: CGRect(x: 0, y: 0, width: 300, height: 120), settings: .defaults),
      equals: CGRect(x: 0, y: 0, width: 200, height: 120)
    )
  }

  @Test("frame: applies gap before right third")
  func frameAppliesGapBeforeRightThird() throws {
    let grid = try #require(
      WindowGrid(rows: 1, columns: 3, x: 2, y: 0, width: 1, height: 1)
    )
    var settings = SpaceSettings.defaults
    settings.gap = 15

    expect(
      grid.frame(in: CGRect(x: 0, y: 0, width: 300, height: 120), settings: settings),
      equals: CGRect(x: 210, y: 0, width: 90, height: 120)
    )
  }

  @Test("frame: applies trailing gap when grid area remains")
  func frameAppliesTrailingGapWhenGridAreaRemains() throws {
    let grid = try #require(
      WindowGrid(rows: 1, columns: 3, x: 0, y: 0, width: 2, height: 1)
    )
    var settings = SpaceSettings.defaults
    settings.gap = 15

    expect(
      grid.frame(in: CGRect(x: 0, y: 0, width: 300, height: 120), settings: settings),
      equals: CGRect(x: 0, y: 0, width: 195, height: 120)
    )
  }

  @Test("frame: applies per-side padding")
  func frameAppliesPerSidePadding() throws {
    let grid = try #require(
      WindowGrid(rows: 1, columns: 1, x: 0, y: 0, width: 1, height: 1)
    )
    var settings = SpaceSettings.defaults
    settings.padding = SpacePadding(top: 10, bottom: 20, left: 30, right: 40)

    expect(
      grid.frame(in: CGRect(x: 0, y: 0, width: 300, height: 200), settings: settings),
      equals: CGRect(x: 30, y: 10, width: 230, height: 170)
    )
  }

  @Test(
    "frame: rejects padding and gaps that exhaust either dimension",
    arguments: [120, 300, Int.max]
  )
  func frameRejectsPaddingAndGapsThatExhaustEitherDimension(value: Int) throws {
    let grid = try #require(WindowGrid(argument: "3:3:1:1:1:1"))
    let bounds = CGRect(x: -1440, y: -900, width: 300, height: 120)
    #expect(
      grid.frame(
        in: bounds,
        settings: SpaceSettings(
          padding: SpacePadding(top: value, bottom: value, left: value, right: value),
          gap: 0
        )
      ) == nil
    )
    #expect(grid.frame(in: bounds, settings: SpaceSettings(padding: .zero, gap: value)) == nil)
  }

  @Test(
    "frame: rejects nonfinite and nonpositive bounds",
    arguments: [CGFloat.nan, .infinity, -.infinity, 0, -1]
  )
  func frameRejectsNonfiniteAndNonpositiveBounds(value: CGFloat) throws {
    let grid = try #require(WindowGrid(argument: "1:1:0:0:1:1"))
    #expect(
      grid.frame(in: CGRect(x: 0, y: 0, width: value, height: 100), settings: .defaults) == nil
    )
    #expect(
      grid.frame(in: CGRect(x: 0, y: 0, width: 100, height: value), settings: .defaults) == nil
    )
    if !value.isFinite {
      #expect(
        grid.frame(in: CGRect(x: value, y: 0, width: 100, height: 100), settings: .defaults) == nil
      )
      #expect(
        grid.frame(in: CGRect(x: 0, y: value, width: 100, height: 100), settings: .defaults) == nil
      )
    }
  }

  @Test("frame: handles large grid counts and padding without integer overflow")
  func frameHandlesLargeGridCountsAndPaddingWithoutIntegerOverflow() throws {
    let grid = try #require(
      WindowGrid(rows: Int.max, columns: Int.max, x: 0, y: 0, width: Int.max, height: Int.max)
    )
    let bounds = CGRect(x: 0, y: 0, width: CGFloat(Int.max) * 4, height: CGFloat(Int.max) * 4)
    let settings = SpaceSettings(
      padding: SpacePadding(top: Int.max, bottom: Int.max, left: Int.max, right: Int.max),
      gap: Int.max
    )
    let frame = try #require(grid.frame(in: bounds, settings: settings))
    #expect(
      frame
        == CGRect(
          x: CGFloat(Int.max),
          y: CGFloat(Int.max),
          width: CGFloat(Int.max) * 2,
          height: CGFloat(Int.max) * 2
        )
    )
  }

  private func expect(_ frame: CGRect?, equals expected: CGRect) {
    guard let actual = frame else {
      Issue.record("Expected usable grid frame")
      return
    }
    #expect(abs(actual.origin.x - expected.origin.x) < 0.0001)
    #expect(abs(actual.origin.y - expected.origin.y) < 0.0001)
    #expect(abs(actual.size.width - expected.size.width) < 0.0001)
    #expect(abs(actual.size.height - expected.size.height) < 0.0001)
  }
}
