import CoreGraphics

/// Pure ordered geometry calculator that recursively bisects the remaining bounds.
struct DwindleLayout {
  /// Minimum frame size accepted for every tiled window.
  private static let minimumWindowSize = CGSize(width: 1, height: 1)

  /// Calculate frames for persistent dwindle sibling relationships.
  func layout(
    tree: TilingTree?,
    in bounds: CGRect,
    settings: SpaceSettings,
    minimumSizes: [CGWindowID: CGSize] = [:]
  ) -> TilingLayoutResult {
    guard let tree else { return .frames([:]) }

    let usableBounds = settings.tilingBounds(in: bounds)
    guard usableBounds.size.meetsTilingMinimum(Self.minimumWindowSize) else {
      return .insufficientSpace(.usableBounds)
    }

    if !minimumSizes.isEmpty {
      var budget = 50_000
      if let frames = constrainedLayout(
        tree,
        bounds: usableBounds,
        gap: settings.tilingGap,
        minima: minimumSizes,
        budget: &budget
      ) {
        return .frames(frames)
      }
      return .insufficientSpace(.usableBounds)
    }

    let gap = settings.tilingGap
    var framesByWindowID = [CGWindowID: CGRect]()
    if let constraint = layout(
      tree,
      in: usableBounds,
      gap: gap,
      framesByWindowID: &framesByWindowID
    ) {
      return .insufficientSpace(constraint)
    }
    return .frames(framesByWindowID)
  }

  /// Resolve dynamic branch directions from their current bounds and retain them in a copy.
  func resolvingSplitDirections(
    in tree: TilingTree?,
    bounds: CGRect,
    settings: SpaceSettings
  ) -> TilingTree? {
    guard let tree else { return nil }
    return resolvingSplitDirections(
      in: tree,
      bounds: settings.tilingBounds(in: bounds),
      gap: settings.tilingGap
    )
  }

  /// Search point-aligned allocations nearest the requested ratio. Dynamic directions
  /// are evaluated from each candidate region, never retained between attempts.
  /// The shared budget bounds work even for deeply nested trees.
  private func constrainedLayout(
    _ tree: TilingTree,
    bounds: CGRect,
    gap: CGFloat,
    minima: [CGWindowID: CGSize],
    budget: inout Int
  ) -> [CGWindowID: CGRect]? {
    guard budget > 0 else { return nil }
    budget -= 1
    let required = minimumSize(tree, gap: gap, minima: minima)
    guard bounds.width >= required.width, bounds.height >= required.height else { return nil }
    switch tree {
    case .leaf(let id):
      return [id: bounds]
    case .branch(let first, let second, let split):
      let vertical = (split.direction ?? direction(for: bounds)) == .vertical
      let available = (vertical ? bounds.width : bounds.height) - gap
      let firstMinimum = minimumSize(first, gap: gap, minima: minima)
      let secondMinimum = minimumSize(second, gap: gap, minima: minima)
      let lower = ceil(vertical ? firstMinimum.width : firstMinimum.height)
      let upper = floor(available - (vertical ? secondMinimum.width : secondMinimum.height))
      guard lower <= upper else { return nil }
      let preferred = min(upper, max(lower, (available * split.ratio).rounded()))
      var distance: CGFloat = 0
      while budget > 0, preferred - distance >= lower || preferred + distance <= upper {
        let candidates = distance == 0 ? [preferred] : [preferred - distance, preferred + distance]
        for allocation in candidates where allocation >= lower && allocation <= upper {
          let (a, b) = dividedBounds(
            bounds,
            gap: gap,
            vertical: vertical,
            allocation: allocation
          )
          if let leading = constrainedLayout(
            first,
            bounds: a,
            gap: gap,
            minima: minima,
            budget: &budget
          ),
            let trailing = constrainedLayout(
              second,
              bounds: b,
              gap: gap,
              minima: minima,
              budget: &budget
            )
          {
            return leading.merging(trailing) { _, new in new }
          }
        }
        distance += 1
      }
      return nil
    }
  }

  /// Fixed branches add descendant requirements and gaps. Dynamic branches use
  /// a conservative lower bound until their actual candidate bounds are known.
  private func minimumSize(
    _ tree: TilingTree,
    gap: CGFloat,
    minima: [CGWindowID: CGSize]
  ) -> CGSize {
    switch tree {
    case .leaf(let id):
      let size = minima[id] ?? Self.minimumWindowSize
      return CGSize(width: max(1, size.width), height: max(1, size.height))
    case .branch(let first, let second, let split):
      let a = minimumSize(first, gap: gap, minima: minima)
      let b = minimumSize(second, gap: gap, minima: minima)
      return CGSize(
        width: split.direction == .vertical ? a.width + gap + b.width : max(a.width, b.width),
        height: split.direction == .horizontal ? a.height + gap + b.height : max(a.height, b.height)
      )
    }
  }

  /// Recursively calculate leaf frames from the retained binary tree.
  private func layout(
    _ tree: TilingTree,
    in bounds: CGRect,
    gap: CGFloat,
    framesByWindowID: inout [CGWindowID: CGRect]
  ) -> TilingLayoutConstraint? {
    switch tree {
    case .leaf(let windowID):
      guard bounds.size.meetsTilingMinimum(Self.minimumWindowSize) else {
        return bounds.width < Self.minimumWindowSize.width ? .tileWidth : .tileHeight
      }
      framesByWindowID[windowID] = bounds
      return nil
    case .branch(let first, let second, let split):
      switch splitBounds(bounds, gap: gap, split: split) {
      case .frames(let firstBounds, let secondBounds):
        return layout(first, in: firstBounds, gap: gap, framesByWindowID: &framesByWindowID)
          ?? layout(second, in: secondBounds, gap: gap, framesByWindowID: &framesByWindowID)
      case .insufficientSpace(let constraint):
        return constraint
      }
    }
  }

  /// Resolve unset directions recursively while preserving existing branch ratios.
  private func resolvingSplitDirections(
    in tree: TilingTree,
    bounds: CGRect,
    gap: CGFloat
  ) -> TilingTree {
    switch tree {
    case .leaf:
      return tree
    case .branch(let first, let second, var split):
      split.direction = split.direction ?? direction(for: bounds)
      guard
        case .frames(let firstBounds, let secondBounds) = splitBounds(
          bounds,
          gap: gap,
          split: split
        )
      else {
        return .branch(first, second, split: split)
      }
      return .branch(
        resolvingSplitDirections(in: first, bounds: firstBounds, gap: gap),
        resolvingSplitDirections(in: second, bounds: secondBounds, gap: gap),
        split: split
      )
    }
  }

  /// Select a split direction from the longest edge of the current bounds.
  private func direction(for bounds: CGRect) -> TilingSplitDirection {
    bounds.width >= bounds.height ? .vertical : .horizontal
  }

  /// Divide bounds using retained geometry or the current longest edge.
  private func splitBounds(
    _ bounds: CGRect,
    gap: CGFloat,
    split: TilingSplit
  ) -> SplitResult {
    let vertical = (split.direction ?? direction(for: bounds)) == .vertical
    let available = (vertical ? bounds.width : bounds.height) - gap
    guard available >= 0 else {
      return .insufficientSpace(vertical ? .horizontalGap : .verticalGap)
    }
    let allocation = (available * min(max(split.ratio, 0.1), 0.9)).rounded()
    let minimum = vertical ? Self.minimumWindowSize.width : Self.minimumWindowSize.height
    guard allocation >= minimum, available - allocation >= minimum else {
      return .insufficientSpace(vertical ? .tileWidth : .tileHeight)
    }
    let (first, second) = dividedBounds(
      bounds,
      gap: gap,
      vertical: vertical,
      allocation: allocation
    )
    return .frames(first, second)
  }

  /// Construct sibling rectangles after the caller chooses a feasible allocation.
  private func dividedBounds(
    _ bounds: CGRect,
    gap: CGFloat,
    vertical: Bool,
    allocation: CGFloat
  ) -> (CGRect, CGRect) {
    var first = bounds
    var second = bounds
    if vertical {
      first.size.width = allocation
      second.origin.x += allocation + gap
      second.size.width = bounds.width - gap - allocation
    } else {
      first.size.height = allocation
      second.origin.y += allocation + gap
      second.size.height = bounds.height - gap - allocation
    }
    return (first, second)
  }
}

/// Internal outcome from splitting one remaining dwindle region.
private enum SplitResult {
  /// Leading window frame and bounds retained for later windows.
  case frames(CGRect, CGRect)

  /// The split cannot satisfy gap or minimum-size constraints.
  case insufficientSpace(TilingLayoutConstraint)
}
