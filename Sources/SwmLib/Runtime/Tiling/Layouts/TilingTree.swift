import CoreGraphics

indirect enum TilingTree: Equatable {
  case leaf(CGWindowID)

  case branch(TilingTree, TilingTree, split: TilingSplit = .equal)

  private enum Match {
    case leaf(CGWindowID)

    case parent(of: CGWindowID, hiding: Set<CGWindowID>)
  }

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

  var windowIDs: [CGWindowID] {
    switch self {
    case .leaf(let windowID):
      return [windowID]
    case .branch(let first, let second, _):
      return first.windowIDs + second.windowIDs
    }
  }

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

  mutating func swap(_ firstWindowID: CGWindowID, with secondWindowID: CGWindowID) -> Bool {
    let windowIDs = windowIDs
    guard firstWindowID != secondWindowID else { return windowIDs.contains(firstWindowID) }
    guard windowIDs.contains(firstWindowID), windowIDs.contains(secondWindowID) else {
      return false
    }

    self = swappingWindows(firstWindowID, secondWindowID)
    return true
  }

  @discardableResult
  mutating func changeSplitRatio(
    _ change: LayoutRatioChange,
    containing windowID: CGWindowID,
    hiding hiddenWindowIDs: Set<CGWindowID> = []
  ) -> CGFloat? {
    updateFirst(.parent(of: windowID, hiding: hiddenWindowIDs)) { tree in
      guard case .branch(let first, let second, var split) = tree else { return nil }
      let isFirst = first.windowIDs.contains(windowID)
      let selectedRatio = change.applying(to: isFirst ? split.ratio : 1 - split.ratio)
      split.ratio = isFirst ? selectedRatio : 1 - selectedRatio
      tree = .branch(first, second, split: split)
      return selectedRatio
    }
  }

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

  private func matches(_ match: Match) -> Bool {
    switch (match, self) {
    case (.leaf(let windowID), .leaf(let candidate)):
      candidate == windowID
    case (.parent(let windowID, let hiddenWindowIDs), .branch(let first, let second, _)):
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

struct TilingSplit: Equatable {
  static let equal = TilingSplit(ratio: 0.5, direction: nil)

  var ratio: CGFloat

  var direction: TilingSplitDirection?
}

enum TilingSplitDirection: Equatable {
  case vertical

  case horizontal
}
