import CoreGraphics
import Testing

@testable import SwmLib

@Suite("WindowGrid")
struct WindowGridTests {
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
      equals: CGRect(x: 205, y: 0, width: 95, height: 120)
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
      equals: CGRect(x: 0, y: 0, width: 190, height: 120)
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

  @Test("frame: ignores disabled padding and gap")
  func frameIgnoresDisabledPaddingAndGap() throws {
    let grid = try #require(
      WindowGrid(rows: 1, columns: 3, x: 1, y: 0, width: 1, height: 1)
    )
    var settings = SpaceSettings.defaults
    settings.paddingEnabled = false
    settings.gapEnabled = false
    settings.padding = SpacePadding(top: 10, bottom: 10, left: 10, right: 10)
    settings.gap = 15

    expect(
      grid.frame(in: CGRect(x: 0, y: 0, width: 300, height: 120), settings: settings),
      equals: CGRect(x: 100, y: 0, width: 100, height: 120)
    )
  }

  private func expect(_ actual: CGRect, equals expected: CGRect) {
    #expect(abs(actual.origin.x - expected.origin.x) < 0.0001)
    #expect(abs(actual.origin.y - expected.origin.y) < 0.0001)
    #expect(abs(actual.size.width - expected.size.width) < 0.0001)
    #expect(abs(actual.size.height - expected.size.height) < 0.0001)
  }
}
