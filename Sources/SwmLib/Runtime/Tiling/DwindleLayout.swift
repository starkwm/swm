import CoreGraphics

/// Pure ordered geometry calculator that recursively bisects the remaining bounds.
struct DwindleLayout {
  /// Minimum frame size accepted for every tiled window.
  private static let minimumWindowSize = CGSize(width: 1, height: 1)

  /// Calculate frames for persistent dwindle sibling relationships.
  func layout(
    tree: TilingTree?,
    in bounds: CGRect,
    settings: SpaceSettings
  ) -> TilingLayoutResult {
    guard let tree else { return .frames([:]) }

    let usableBounds = settings.tilingBounds(in: bounds)
    guard usableBounds.size.meetsTilingMinimum(Self.minimumWindowSize) else {
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
    switch split.direction ?? direction(for: bounds) {
    case .vertical:
      return splitVertically(bounds, gap: gap, ratio: split.ratio)
    case .horizontal:
      return splitHorizontally(bounds, gap: gap, ratio: split.ratio)
    }
  }

  /// Split a landscape region into leading and remaining columns.
  private func splitVertically(
    _ bounds: CGRect,
    gap: CGFloat,
    ratio: CGFloat
  ) -> SplitResult {
    let availableWidth = bounds.width - gap
    guard availableWidth >= 0 else { return .insufficientSpace(.horizontalGap) }

    let leadingWidth = (availableWidth * min(max(ratio, 0.1), 0.9)).rounded()
    let trailingWidth = availableWidth - leadingWidth
    guard
      leadingWidth >= Self.minimumWindowSize.width,
      trailingWidth >= Self.minimumWindowSize.width
    else {
      return .insufficientSpace(.tileWidth)
    }

    return .frames(
      CGRect(
        x: bounds.minX,
        y: bounds.minY,
        width: leadingWidth,
        height: bounds.height
      ),
      CGRect(
        x: bounds.minX + leadingWidth + gap,
        y: bounds.minY,
        width: trailingWidth,
        height: bounds.height
      )
    )
  }

  /// Split a portrait region into leading and remaining rows.
  private func splitHorizontally(
    _ bounds: CGRect,
    gap: CGFloat,
    ratio: CGFloat
  ) -> SplitResult {
    let availableHeight = bounds.height - gap
    guard availableHeight >= 0 else { return .insufficientSpace(.verticalGap) }

    let leadingHeight = (availableHeight * min(max(ratio, 0.1), 0.9)).rounded()
    let trailingHeight = availableHeight - leadingHeight
    guard
      leadingHeight >= Self.minimumWindowSize.height,
      trailingHeight >= Self.minimumWindowSize.height
    else {
      return .insufficientSpace(.tileHeight)
    }

    return .frames(
      CGRect(
        x: bounds.minX,
        y: bounds.minY,
        width: bounds.width,
        height: leadingHeight
      ),
      CGRect(
        x: bounds.minX,
        y: bounds.minY + leadingHeight + gap,
        width: bounds.width,
        height: trailingHeight
      )
    )
  }
}

/// Internal outcome from splitting one remaining dwindle region.
private enum SplitResult {
  /// Leading window frame and bounds retained for later windows.
  case frames(CGRect, CGRect)

  /// The split cannot satisfy gap or minimum-size constraints.
  case insufficientSpace(TilingLayoutConstraint)
}
