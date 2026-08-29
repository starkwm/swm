import CoreGraphics

@testable import SwmLib

func tilingTree(_ windowIDs: [CGWindowID]) -> TilingTree? {
  guard let firstWindowID = windowIDs.first, firstWindowID != 0 else { return nil }

  var tree = TilingTree.leaf(firstWindowID)
  for windowID in windowIDs.dropFirst() {
    tree.insert(windowID, beside: tree.windowIDs.last)
  }
  return tree
}
