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
    case .branch(let first, let second):
      let split =
        bounds.width >= bounds.height
        ? splitVertically(bounds, gap: gap)
        : splitHorizontally(bounds, gap: gap)
      switch split {
      case .frames(let firstBounds, let secondBounds):
        return layout(first, in: firstBounds, gap: gap, framesByWindowID: &framesByWindowID)
          ?? layout(second, in: secondBounds, gap: gap, framesByWindowID: &framesByWindowID)
      case .insufficientSpace(let constraint):
        return constraint
      }
    }
  }

  /// Split a landscape region into leading and remaining columns.
  private func splitVertically(_ bounds: CGRect, gap: CGFloat) -> SplitResult {
    let availableWidth = bounds.width - gap
    guard availableWidth >= 0 else { return .insufficientSpace(.horizontalGap) }

    let leadingWidth = (availableWidth / 2).rounded()
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
  private func splitHorizontally(_ bounds: CGRect, gap: CGFloat) -> SplitResult {
    let availableHeight = bounds.height - gap
    guard availableHeight >= 0 else { return .insufficientSpace(.verticalGap) }

    let leadingHeight = (availableHeight / 2).rounded()
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
