import CoreGraphics

/// Pure ordered master layout geometry calculator.
struct MasterLayout {
  /// Minimum frame size accepted for every tiled window.
  private static let minimumWindowSize = CGSize(width: 1, height: 1)

  /// Calculate master layout frames without performing window side effects.
  func layout(
    windowIDs: [CGWindowID],
    in bounds: CGRect,
    settings: SpaceSettings,
    masterRatio: CGFloat = 0.5
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
    let availableWidth = usableBounds.width - gap
    guard availableWidth >= 0 else {
      return .insufficientSpace(.horizontalGap)
    }

    let ratio = min(max(masterRatio, 0.1), 0.9)
    let masterWidth = (availableWidth * ratio).rounded()
    let stackWidth = availableWidth - masterWidth
    guard masterWidth >= Self.minimumWindowSize.width else {
      return .insufficientSpace(.masterWidth)
    }
    guard stackWidth >= Self.minimumWindowSize.width else {
      return .insufficientSpace(.stackWidth)
    }

    let stackWindowIDs = Array(windowIDs.dropFirst())
    guard
      let stackHeights = partitions(
        length: usableBounds.height,
        count: stackWindowIDs.count,
        gap: gap,
        minimum: Self.minimumWindowSize.height
      )
    else {
      return .insufficientSpace(.stackHeight)
    }

    var framesByWindowID = [
      windowIDs[0]: CGRect(
        x: usableBounds.minX,
        y: usableBounds.minY,
        width: masterWidth,
        height: usableBounds.height
      )
    ]
    let stackX = usableBounds.minX + masterWidth + gap
    var stackY = usableBounds.minY

    for (index, windowID) in stackWindowIDs.enumerated() {
      let height = stackHeights[index]
      framesByWindowID[windowID] = CGRect(
        x: stackX,
        y: stackY,
        width: stackWidth,
        height: height
      )
      stackY += height + gap
    }

    return .frames(framesByWindowID)
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

  /// Return rounded partition lengths whose total plus gaps exactly fills the input length.
  private func partitions(
    length: CGFloat,
    count: Int,
    gap: CGFloat,
    minimum: CGFloat
  ) -> [CGFloat]? {
    guard count > 0 else { return [] }

    let availableLength = length - gap * CGFloat(count - 1)
    guard availableLength >= 0 else { return nil }

    let lengths = (0..<count).map { index in
      let start = (availableLength * CGFloat(index) / CGFloat(count)).rounded()
      let end = (availableLength * CGFloat(index + 1) / CGFloat(count)).rounded()
      return end - start
    }

    return lengths.allSatisfy { $0 >= minimum } ? lengths : nil
  }

  /// Return whether a frame size satisfies the configured minimum.
  private func satisfiesMinimum(_ size: CGSize) -> Bool {
    size.width >= Self.minimumWindowSize.width && size.height >= Self.minimumWindowSize.height
  }
}
