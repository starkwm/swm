import CoreGraphics

/// Persistent binary relationships and stable order for tiled windows.
indirect enum TilingTree: Equatable {
  /// A tiled window.
  case leaf(CGWindowID)

  /// Two sibling subtrees sharing one layout region.
  case branch(TilingTree, TilingTree, split: TilingSplit = .equal)

  /// Window IDs in stable tree order.
  var windowIDs: [CGWindowID] {
    switch self {
    case .leaf(let windowID):
      return [windowID]
    case .branch(let first, let second, _):
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
    case .branch(let first, let second, let split):
      switch (first.removing(windowIDs), second.removing(windowIDs)) {
      case (.some(let first), .some(let second)):
        return .branch(first, second, split: split)
      case (.some(let remaining), .none), (.none, .some(let remaining)):
        return remaining
      case (.none, .none):
        return nil
      }
    }
  }

  /// Swap two window leaves while retaining branch geometry.
  mutating func swap(_ firstWindowID: CGWindowID, with secondWindowID: CGWindowID) -> Bool {
    let windowIDs = windowIDs
    guard firstWindowID != secondWindowID else { return windowIDs.contains(firstWindowID) }
    guard windowIDs.contains(firstWindowID), windowIDs.contains(secondWindowID) else {
      return false
    }

    self = swappingWindows(firstWindowID, secondWindowID)
    return true
  }

  /// Change the nearest parent split for a window leaf.
  @discardableResult
  mutating func changeSplitRatio(
    _ change: LayoutRatioChange,
    containing windowID: CGWindowID
  ) -> CGFloat? {
    switch self {
    case .leaf:
      return nil
    case .branch(var first, var second, var split):
      if case .leaf(let candidate) = first, candidate == windowID {
        split.ratio = change.applying(to: split.ratio)
        self = .branch(first, second, split: split)
        return split.ratio
      }
      if case .leaf(let candidate) = second, candidate == windowID {
        let selectedRatio = change.applying(to: 1 - split.ratio)
        split.ratio = 1 - selectedRatio
        self = .branch(first, second, split: split)
        return selectedRatio
      }

      if let ratio = first.changeSplitRatio(change, containing: windowID) {
        self = .branch(first, second, split: split)
        return ratio
      }
      if let ratio = second.changeSplitRatio(change, containing: windowID) {
        self = .branch(first, second, split: split)
        return ratio
      }
      return nil
    }
  }

  /// Toggle the nearest resolved parent split containing a window leaf.
  mutating func toggleSplitDirection(containing windowID: CGWindowID) -> Bool {
    switch self {
    case .leaf:
      return false
    case .branch(var first, var second, var split):
      let containsDirectLeaf: Bool
      switch (first, second) {
      case (.leaf(let candidate), _) where candidate == windowID,
        (_, .leaf(let candidate)) where candidate == windowID:
        containsDirectLeaf = true
      default:
        containsDirectLeaf = false
      }

      if containsDirectLeaf {
        guard let direction = split.direction else { return false }
        split.direction = direction == .vertical ? .horizontal : .vertical
        self = .branch(first, second, split: split)
        return true
      }
      if first.toggleSplitDirection(containing: windowID) {
        self = .branch(first, second, split: split)
        return true
      }
      if second.toggleSplitDirection(containing: windowID) {
        self = .branch(first, second, split: split)
        return true
      }
      return false
    }
  }

  /// Return a copy whose branches dynamically resolve their split directions.
  func clearingSplitDirections() -> TilingTree {
    switch self {
    case .leaf:
      return self
    case .branch(let first, let second, var split):
      split.direction = nil
      return .branch(
        first.clearingSplitDirections(),
        second.clearingSplitDirections(),
        split: split
      )
    }
  }

  /// Replace one leaf while preserving every other branch relationship.
  private mutating func replaceLeaf(_ windowID: CGWindowID, with replacement: TilingTree) -> Bool {
    switch self {
    case .leaf(let candidate):
      guard candidate == windowID else { return false }
      self = replacement
      return true
    case .branch(var first, var second, let split):
      if first.replaceLeaf(windowID, with: replacement) {
        self = .branch(first, second, split: split)
        return true
      }
      if second.replaceLeaf(windowID, with: replacement) {
        self = .branch(first, second, split: split)
        return true
      }
      return false
    }
  }

  /// Return a copy with two leaf identifiers exchanged.
  private func swappingWindows(
    _ firstWindowID: CGWindowID,
    _ secondWindowID: CGWindowID
  ) -> TilingTree {
    switch self {
    case .leaf(let windowID):
      if windowID == firstWindowID {
        return .leaf(secondWindowID)
      }
      if windowID == secondWindowID {
        return .leaf(firstWindowID)
      }
      return self
    case .branch(let first, let second, let split):
      return .branch(
        first.swappingWindows(firstWindowID, secondWindowID),
        second.swappingWindows(firstWindowID, secondWindowID),
        split: split
      )
    }
  }
}

/// Geometry retained for one dwindle branch.
struct TilingSplit: Equatable {
  /// Default equal split with direction selected from current bounds.
  static let equal = TilingSplit(ratio: 0.5, direction: nil)

  /// Fraction assigned to the first subtree.
  var ratio: CGFloat

  /// Fixed split direction, or nil to follow the current longest edge.
  var direction: TilingSplitDirection?
}

/// Direction in which a dwindle branch divides its bounds.
enum TilingSplitDirection: Equatable {
  /// Divide the bounds into leading and trailing columns.
  case vertical

  /// Divide the bounds into upper and lower rows.
  case horizontal
}
