import CoreGraphics

/// Persistent binary relationships and stable order for tiled windows.
indirect enum TilingTree: Equatable {
  /// A tiled window.
  case leaf(CGWindowID)

  /// Two sibling subtrees sharing one layout region.
  case branch(TilingTree, TilingTree)

  /// Window IDs in stable tree order.
  var windowIDs: [CGWindowID] {
    switch self {
    case .leaf(let windowID):
      return [windowID]
    case .branch(let first, let second):
      return first.windowIDs + second.windowIDs
    }
  }

  /// Insert a new sibling beside the focused leaf, or the final leaf as fallback.
  mutating func insert(_ windowID: CGWindowID, beside focusedWindowID: CGWindowID?) {
    guard windowID != 0, !windowIDs.contains(windowID) else { return }

    let anchor =
      focusedWindowID.flatMap { windowIDs.contains($0) ? $0 : nil }
      ?? windowIDs.last
    guard let anchor else { return }
    _ = replaceLeaf(anchor, with: .branch(.leaf(anchor), .leaf(windowID)))
  }

  /// Return a copy with omitted leaves removed and unary branches collapsed.
  func removing(_ windowIDs: Set<CGWindowID>) -> TilingTree? {
    switch self {
    case .leaf(let windowID):
      return windowIDs.contains(windowID) ? nil : self
    case .branch(let first, let second):
      switch (first.removing(windowIDs), second.removing(windowIDs)) {
      case (.some(let first), .some(let second)):
        return .branch(first, second)
      case (.some(let remaining), .none), (.none, .some(let remaining)):
        return remaining
      case (.none, .none):
        return nil
      }
    }
  }

  /// Replace one leaf while preserving every other branch relationship.
  private mutating func replaceLeaf(_ windowID: CGWindowID, with replacement: TilingTree) -> Bool {
    switch self {
    case .leaf(let candidate):
      guard candidate == windowID else { return false }
      self = replacement
      return true
    case .branch(var first, var second):
      if first.replaceLeaf(windowID, with: replacement) {
        self = .branch(first, second)
        return true
      }
      if second.replaceLeaf(windowID, with: replacement) {
        self = .branch(first, second)
        return true
      }
      return false
    }
  }
}
