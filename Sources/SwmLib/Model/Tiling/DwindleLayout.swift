import CoreGraphics

/// Pure ordered geometry calculator that recursively bisects the remaining bounds.
struct DwindleLayout {
  /// Minimum frame size accepted for every tiled window.
  private static let minimumWindowSize = CGSize(width: 1, height: 1)

  /// Calculate dwindle frames without performing window side effects.
  func layout(
    windowIDs: [CGWindowID],
    in bounds: CGRect,
    settings: SpaceSettings
  ) -> TilingLayoutResult {
    layout(tree: TilingTree(windowIDs: windowIDs), in: bounds, settings: settings)
  }

  /// Calculate frames for persistent dwindle sibling relationships.
  func layout(
    tree: TilingTree?,
    in bounds: CGRect,
    settings: SpaceSettings
  ) -> TilingLayoutResult {
    guard let tree else { return .frames([:]) }

    let usableBounds = usableBounds(in: bounds, settings: settings)
    guard satisfiesMinimum(usableBounds.size) else {
      return .insufficientSpace(.usableBounds)
    }

    let gap = settings.gapEnabled ? CGFloat(max(0, settings.gap)) : 0
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
      guard satisfiesMinimum(bounds.size) else {
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

  /// Apply enabled per-Space padding to visible display bounds.
  private func usableBounds(in bounds: CGRect, settings: SpaceSettings) -> CGRect {
    guard settings.paddingEnabled else { return bounds }

    let top = CGFloat(max(0, settings.padding.top))
    let bottom = CGFloat(max(0, settings.padding.bottom))
    let left = CGFloat(max(0, settings.padding.left))
    let right = CGFloat(max(0, settings.padding.right))

    return CGRect(
      x: bounds.minX + left,
      y: bounds.minY + top,
      width: max(0, bounds.width - left - right),
      height: max(0, bounds.height - top - bottom)
    )
  }

  /// Return whether a frame size satisfies the configured minimum.
  private func satisfiesMinimum(_ size: CGSize) -> Bool {
    size.width >= Self.minimumWindowSize.width && size.height >= Self.minimumWindowSize.height
  }
}

/// Internal outcome from splitting one remaining dwindle region.
private enum SplitResult {
  /// Leading window frame and bounds retained for later windows.
  case frames(CGRect, CGRect)

  /// The split cannot satisfy gap or minimum-size constraints.
  case insufficientSpace(TilingLayoutConstraint)
}
