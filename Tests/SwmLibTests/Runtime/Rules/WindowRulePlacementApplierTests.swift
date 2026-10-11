import CoreGraphics
import Testing

@testable import SwmLib

@Suite("WindowRulePlacement")
struct WindowRulePlacementTests {
  @Test("frame: applies grids in destination bounds and preserves display placement")
  func frameAppliesGridsInDestinationBoundsAndPreservesDisplayPlacement() throws {
    let source = CGRect(x: 0, y: 0, width: 1_000, height: 800)
    let target = CGRect(x: 1_000, y: -100, width: 1_600, height: 1_000)
    let original = CGRect(x: 100, y: 100, width: 500, height: 400)
    let placement = WindowRulePlacement(
      grid: try #require(WindowGrid(argument: "2:1:1:0:1:1")),
      display: .index(2)
    )
    #expect(
      placement.frame(
        from: original,
        sourceBounds: source,
        targetBounds: target,
        settings: .defaults
      )
        == CGRect(x: 1_800, y: -100, width: 800, height: 1_000)
    )
    var settings = SpaceSettings.defaults
    settings.padding = SpacePadding(top: 10, bottom: 10, left: 20, right: 20)
    #expect(
      placement.frame(
        from: original,
        sourceBounds: source,
        targetBounds: target,
        settings: settings
      )
        == CGRect(x: 1_800, y: -90, width: 780, height: 980)
    )
    #expect(
      WindowRulePlacement(display: .index(2)).frame(
        from: original,
        sourceBounds: source,
        targetBounds: target,
        settings: .defaults
      )
        == CGRect(x: 1_220, y: 50, width: 500, height: 400)
    )
  }

  @Test("frame: rejects exhausted destination bounds", arguments: [300, Int.max])
  func frameRejectsExhaustedDestinationBounds(value: Int) throws {
    let grid = try #require(WindowGrid(argument: "2:1:1:0:1:1"))
    let placement = WindowRulePlacement(grid: grid)
    let bounds = CGRect(x: -1440, y: -900, width: 300, height: 120)
    #expect(
      placement.frame(
        from: bounds,
        sourceBounds: bounds,
        targetBounds: bounds,
        settings: SpaceSettings(padding: .zero, gap: value)
      ) == nil
    )
  }
}
