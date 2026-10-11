import CoreGraphics
import Testing

@testable import SwmLib

@Suite("TilingTree")
struct TilingTreeTests {
  @Test("insert: falls back to the final leaf")
  func insertFallsBackToTheFinalLeaf() throws {
    var tree = try #require(tilingTree([1, 2]))

    tree.insert(3, beside: nil)
    tree.insert(4, beside: 99)
    tree.insert(3, beside: 1)
    tree.insert(0, beside: 1)

    #expect(tree.windowIDs == [1, 2, 3, 4])
  }

  @Test("changeSplitRatio: updates the nearest parent and clamps the ratio")
  func changeSplitRatioUpdatesTheNearestParentAndClampsTheRatio() throws {
    var tree = try #require(tilingTree([1, 2, 3]))

    let relativeRatio = tree.changeSplitRatio(.relative(0.2), containing: 2)
    let absoluteRatio = tree.changeSplitRatio(.absolute(2), containing: 3)
    let missingRatio = tree.changeSplitRatio(.absolute(0.4), containing: 99)

    #expect(relativeRatio == 0.7)
    #expect(absoluteRatio == 0.9)
    #expect(missingRatio == nil)

    #expect(
      DwindleLayout().layout(
        tree: tree,
        in: CGRect(x: 0, y: 0, width: 1000, height: 800),
        settings: .defaults
      )
        == .frames([
          1: CGRect(x: 0, y: 0, width: 500, height: 800),
          2: CGRect(x: 500, y: 0, width: 500, height: 80),
          3: CGRect(x: 500, y: 80, width: 500, height: 720),
        ])
    )
  }
}
