import CoreGraphics

/// Persistent binary relationships and stable order for tiled windows.
indirect enum TilingTree: Equatable {
  /// A tiled window.
  case leaf(CGWindowID)

  /// Two sibling subtrees sharing one layout region.
  case branch(TilingTree, TilingTree, split: TilingSplit = .equal)

  /// A subtree to update, found by a window's leaf.
  private enum Match {
    /// The window's leaf.
    case leaf(CGWindowID)

    /// The window's nearest split once hidden leaves are removed: a branch where one side holds
    /// only the window's leaf and the other side holds a visible window.
    case parent(of: CGWindowID, hiding: Set<CGWindowID>)
  }

  /// Whether a branch's sides hold only a window's leaf and another visible window once hidden
  /// leaves are removed.
  private static func isParent(
    of windowID: CGWindowID,
    first: TilingTree,
    second: TilingTree,
    hiding hiddenWindowIDs: Set<CGWindowID>
  ) -> Bool {
    switch (first.removing(hiddenWindowIDs), second.removing(hiddenWindowIDs)) {
    case (.leaf(windowID), .some), (.some, .leaf(windowID)): true
    default: false
    }
  }

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
  ///
  /// The new branch assigns `ratio` of its region to the existing leaf.
  mutating func insert(
    _ windowID: CGWindowID,
    beside focusedWindowID: CGWindowID?,
    ratio: CGFloat = TilingSplit.equal.ratio
  ) {
    guard windowID != 0, !windowIDs.contains(windowID) else { return }

    let anchor =
      focusedWindowID.flatMap { windowIDs.contains($0) ? $0 : nil }
      ?? windowIDs.last
    guard let anchor else { return }
    let split = TilingSplit(ratio: ratio, direction: nil)
    updateFirst(.leaf(anchor)) {
      $0 = .branch(.leaf(anchor), .leaf(windowID), split: split)
    }
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

  /// Change the nearest visible parent split for a window leaf.
  @discardableResult
  mutating func changeSplitRatio(
    _ change: LayoutRatioChange,
    containing windowID: CGWindowID,
    hiding hiddenWindowIDs: Set<CGWindowID> = []
  ) -> CGFloat? {
    updateFirst(.parent(of: windowID, hiding: hiddenWindowIDs)) { tree in
      guard case .branch(let first, let second, var split) = tree else { return nil }
      // The ratio is the first subtree's share, so a second-side window adjusts its complement.
      let isFirst = first.windowIDs.contains(windowID)
      let selectedRatio = change.applying(to: isFirst ? split.ratio : 1 - split.ratio)
      split.ratio = isFirst ? selectedRatio : 1 - selectedRatio
      tree = .branch(first, second, split: split)
      return selectedRatio
    }
  }

  /// Toggle the nearest resolved visible parent split containing a window leaf.
  mutating func toggleSplitDirection(
    containing windowID: CGWindowID,
    hiding hiddenWindowIDs: Set<CGWindowID> = []
  ) -> Bool {
    updateFirst(.parent(of: windowID, hiding: hiddenWindowIDs)) { tree in
      guard case .branch(let first, let second, var split) = tree,
        let direction = split.direction
      else { return nil }
      split.direction = direction == .vertical ? .horizontal : .vertical
      tree = .branch(first, second, split: split)
      return true
    } ?? false
  }

  /// Exchange the two subtrees of the nearest visible parent containing a window leaf.
  mutating func swapSplit(
    containing windowID: CGWindowID,
    hiding hiddenWindowIDs: Set<CGWindowID> = []
  ) -> Bool {
    updateFirst(.parent(of: windowID, hiding: hiddenWindowIDs)) { tree in
      guard case .branch(let first, let second, let split) = tree else { return nil }
      tree = .branch(second, first, split: split)
      return true
    } ?? false
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

  /// Return a copy with every branch ratio replaced, keeping retained split directions.
  func settingSplitRatios(_ ratio: CGFloat) -> TilingTree {
    switch self {
    case .leaf:
      return self
    case .branch(let first, let second, var split):
      split.ratio = ratio
      return .branch(
        first.settingSplitRatios(ratio),
        second.settingSplitRatios(ratio),
        split: split
      )
    }
  }

  /// Whether this subtree is the one `match` describes.
  private func matches(_ match: Match) -> Bool {
    switch (match, self) {
    case (.leaf(let windowID), .leaf(let candidate)):
      candidate == windowID
    case (.parent(let windowID, let hiddenWindowIDs), .branch(let first, let second, _)):
      // A hidden window has no visible split, so it keeps its full-tree parent.
      Self.isParent(
        of: windowID,
        first: first,
        second: second,
        hiding: hiddenWindowIDs.contains(windowID) ? [] : hiddenWindowIDs
      )
    default:
      false
    }
  }

  /// Apply `body` to the first subtree in tree order that `match` describes, rebuilding the path
  /// to it.
  ///
  /// Returns `body`'s result, or nil when no subtree matches. Only the first match is offered,
  /// so `body` returns nil to leave the tree unchanged.
  @discardableResult
  private mutating func updateFirst<Result>(
    _ match: Match,
    _ body: (inout TilingTree) -> Result?
  ) -> Result? {
    if matches(match) { return body(&self) }
    guard case .branch(var first, var second, let split) = self else { return nil }

    if let result = first.updateFirst(match, body) {
      self = .branch(first, second, split: split)
      return result
    }
    if let result = second.updateFirst(match, body) {
      self = .branch(first, second, split: split)
      return result
    }
    return nil
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
