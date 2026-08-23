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
    guard !windowIDs.isEmpty else { return .frames([:]) }

    let usableBounds = usableBounds(in: bounds, settings: settings)
    guard satisfiesMinimum(usableBounds.size) else {
      return .insufficientSpace(.usableBounds)
    }

    guard windowIDs.count > 1 else {
      return .frames([windowIDs[0]: usableBounds])
    }

    let gap = settings.gapEnabled ? CGFloat(max(0, settings.gap)) : 0
    var framesByWindowID = [CGWindowID: CGRect]()
    var remainingBounds = usableBounds

    for windowID in windowIDs.dropLast() {
      let split: SplitResult
      if remainingBounds.width >= remainingBounds.height {
        split = splitVertically(remainingBounds, gap: gap)
      } else {
        split = splitHorizontally(remainingBounds, gap: gap)
      }

      switch split {
      case .frames(let windowFrame, let remainder):
        framesByWindowID[windowID] = windowFrame
        remainingBounds = remainder
      case .insufficientSpace(let constraint):
        return .insufficientSpace(constraint)
      }
    }

    guard satisfiesMinimum(remainingBounds.size) else {
      return .insufficientSpace(
        remainingBounds.width < Self.minimumWindowSize.width ? .tileWidth : .tileHeight
      )
    }

    framesByWindowID[windowIDs[windowIDs.count - 1]] = remainingBounds
    return .frames(framesByWindowID)
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
