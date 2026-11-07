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

  @Test("toggleSplitDirection: flips only the nearest resolved parent")
  func toggleSplitDirectionFlipsOnlyTheNearestResolvedParent() {
    let vertical = TilingSplit(ratio: 0.5, direction: .vertical)
    let nested = TilingTree.branch(
      .leaf(2),
      .leaf(3),
      split: TilingSplit(ratio: 0.5, direction: nil)
    )
    var tree = TilingTree.branch(.leaf(1), nested, split: vertical)

    let unresolved = tree.toggleSplitDirection(containing: 3)
    let missing = tree.toggleSplitDirection(containing: 99)
    #expect(!unresolved && !missing)
    #expect(tree == .branch(.leaf(1), nested, split: vertical))

    let toggled = tree.toggleSplitDirection(containing: 1)
    #expect(toggled)
    #expect(
      tree == .branch(.leaf(1), nested, split: TilingSplit(ratio: 0.5, direction: .horizontal))
    )
  }

  @Test("swapSplit: exchanges the subtrees of the nearest parent")
  func swapSplitExchangesTheSubtreesOfTheNearestParent() {
    let split = TilingSplit(ratio: 0.3, direction: .vertical)
    var tree = TilingTree.branch(.leaf(1), .branch(.leaf(2), .leaf(3), split: split))

    let swappedNested = tree.swapSplit(containing: 3)
    #expect(swappedNested)
    #expect(tree == .branch(.leaf(1), .branch(.leaf(3), .leaf(2), split: split)))

    let swappedRoot = tree.swapSplit(containing: 1)
    #expect(swappedRoot)
    #expect(tree == .branch(.branch(.leaf(3), .leaf(2), split: split), .leaf(1)))

    let swappedMissing = tree.swapSplit(containing: 99)
    #expect(!swappedMissing)
  }

  @Test("nearest split commands: skip branches whose other side is hidden")
  func nearestSplitCommandsSkipBranchesWhoseOtherSideIsHidden() {
    let vertical = TilingSplit(ratio: 0.5, direction: .vertical)
    let nested = TilingTree.branch(.leaf(2), .leaf(3), split: vertical)
    var tree = TilingTree.branch(.leaf(1), nested, split: vertical)

    let ratio = tree.changeSplitRatio(.absolute(0.2), containing: 2, hiding: [3])
    #expect(ratio == 0.2)
    #expect(tree == .branch(.leaf(1), nested, split: TilingSplit(ratio: 0.8, direction: .vertical)))

    let toggled = tree.toggleSplitDirection(containing: 2, hiding: [3])
    #expect(toggled)
    #expect(
      tree == .branch(.leaf(1), nested, split: TilingSplit(ratio: 0.8, direction: .horizontal))
    )

    let swappedAlone = tree.swapSplit(containing: 2, hiding: [1, 3])
    #expect(!swappedAlone)

    let swappedHidden = tree.swapSplit(containing: 3, hiding: [3])
    #expect(swappedHidden)
    #expect(
      tree
        == .branch(
          .leaf(1),
          .branch(.leaf(3), .leaf(2), split: vertical),
          split: TilingSplit(ratio: 0.8, direction: .horizontal)
        )
    )
  }

  @Test("settingSplitRatios: replaces every ratio and keeps retained directions")
  func settingSplitRatiosReplacesEveryRatioAndKeepsRetainedDirections() {
    let tree = TilingTree.branch(
      .leaf(1),
      .branch(.leaf(2), .leaf(3), split: TilingSplit(ratio: 0.3, direction: nil)),
      split: TilingSplit(ratio: 0.8, direction: .horizontal)
    )

    #expect(
      tree.settingSplitRatios(0.6)
        == .branch(
          .leaf(1),
          .branch(.leaf(2), .leaf(3), split: TilingSplit(ratio: 0.6, direction: nil)),
          split: TilingSplit(ratio: 0.6, direction: .horizontal)
        )
    )
  }
}
