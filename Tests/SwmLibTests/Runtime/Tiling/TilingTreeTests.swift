import Testing

@testable import SwmLib

@Suite("TilingTree")
struct TilingTreeTests {
  @Test("insert: splits the focused leaf and preserves traversal order")
  func insertSplitsFocusedLeaf() throws {
    var tree = try #require(tilingTree([1, 2, 3]))

    tree.insert(4, beside: 1)

    #expect(tree == .branch(.branch(.leaf(1), .leaf(4)), .branch(.leaf(2), .leaf(3))))
    #expect(tree.windowIDs == [1, 4, 2, 3])
  }

  @Test("insert: falls back to the final leaf")
  func insertFallsBackToFinalLeaf() throws {
    var tree = try #require(tilingTree([1, 2]))

    tree.insert(3, beside: nil)
    tree.insert(4, beside: 99)
    tree.insert(3, beside: 1)
    tree.insert(0, beside: 1)

    #expect(tree.windowIDs == [1, 2, 3, 4])
  }

  @Test("removing: collapses the removed leaf's parent")
  func removingCollapsesParent() throws {
    let tree = try #require(tilingTree([1, 2, 3]))

    #expect(tree.removing([2]) == .branch(.leaf(1), .leaf(3)))
    #expect(tree.removing([1, 2, 3]) == nil)
  }

  @Test("removing: restores omitted leaves at their retained position")
  func removingRestoresOmittedLeavesAtRetainedPosition() throws {
    let tree = try #require(tilingTree([1, 2, 3]))

    #expect(tree.removing([2])?.windowIDs == [1, 3])
    #expect(tree.removing([])?.windowIDs == [1, 2, 3])
    #expect(tree.windowIDs == [1, 2, 3])
  }

  @Test("swap: exchanges leaves without changing the tree")
  func swapExchangesLeaves() throws {
    var tree = try #require(tilingTree([1, 2, 3]))

    let swapped = tree.swap(1, with: 3)
    let missing = tree.swap(3, with: 99)

    #expect(swapped)
    #expect(tree.windowIDs == [3, 2, 1])
    #expect(missing == false)
  }

  @Test("changeSplitRatio: updates the nearest parent and clamps the ratio")
  func changeSplitRatioUpdatesNearestParent() throws {
    var tree = try #require(tilingTree([1, 2, 3]))

    let relativeRatio = tree.changeSplitRatio(.relative(0.2), containing: 2)
    let absoluteRatio = tree.changeSplitRatio(.absolute(2), containing: 3)
    let missingRatio = tree.changeSplitRatio(.absolute(0.4), containing: 99)

    #expect(relativeRatio == 0.7)
    #expect(absoluteRatio == 0.9)
    #expect(missingRatio == nil)

    guard case .branch(.leaf(1), .branch(.leaf(2), .leaf(3), let split), _) = tree else {
      Issue.record("expected the original branch structure")
      return
    }
    #expect(abs(split.ratio - 0.1) < 0.000_001)
    #expect(split.direction == nil)
  }

  @Test("clearingSplitDirections: retains ratios and removes directions")
  func clearingSplitDirectionsRetainsRatios() {
    let tree = TilingTree.branch(
      .leaf(1),
      .leaf(2),
      split: TilingSplit(ratio: 0.7, direction: .horizontal)
    )

    #expect(
      tree.clearingSplitDirections()
        == .branch(
          .leaf(1),
          .leaf(2),
          split: TilingSplit(ratio: 0.7, direction: nil)
        )
    )
  }
}
