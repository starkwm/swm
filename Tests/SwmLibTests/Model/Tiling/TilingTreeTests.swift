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
}
