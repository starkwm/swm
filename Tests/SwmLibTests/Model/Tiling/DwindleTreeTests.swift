import Testing

@testable import SwmLib

@Suite("DwindleTree")
struct DwindleTreeTests {
  @Test("insert: splits the focused leaf")
  func insertSplitsFocusedLeaf() throws {
    var tree = try #require(DwindleTree(windowIDs: [1, 2, 3]))

    tree.insert(4, beside: 1)

    #expect(tree == .branch(.branch(.leaf(1), .leaf(4)), .branch(.leaf(2), .leaf(3))))
    #expect(tree.windowIDs == [1, 4, 2, 3])
  }

  @Test("removing: collapses the removed leaf's parent")
  func removingCollapsesParent() throws {
    let tree = try #require(DwindleTree(windowIDs: [1, 2, 3]))

    #expect(tree.removing([2]) == .branch(.leaf(1), .leaf(3)))
    #expect(tree.removing([1, 2, 3]) == nil)
  }
}
