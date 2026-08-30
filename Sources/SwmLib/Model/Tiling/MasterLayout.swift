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
    masterRatio: CGFloat = 0.5,
    placement: MasterPlacement = .left
  ) -> TilingLayoutResult {
    guard !windowIDs.isEmpty else { return .frames([:]) }

    let usableBounds = settings.tilingBounds(in: bounds)
    guard usableBounds.size.meetsTilingMinimum(Self.minimumWindowSize) else {
      return .insufficientSpace(.usableBounds)
    }

    guard windowIDs.count > 1 else {
      return .frames([windowIDs[0]: usableBounds])
    }

    let ratio = min(max(masterRatio, 0.1), 0.9)
    switch placement {
    case .left, .right:
      return columnLayout(
        windowIDs: windowIDs,
        in: usableBounds,
        gap: settings.tilingGap,
        masterRatio: ratio,
        placement: placement
      )
    case .top, .bottom:
      return rowLayout(
        windowIDs: windowIDs,
        in: usableBounds,
        gap: settings.tilingGap,
        masterRatio: ratio,
        placement: placement
      )
    }
  }

  /// Arrange a master column and vertical stack on the left or right.
  private func columnLayout(
    windowIDs: [CGWindowID],
    in bounds: CGRect,
    gap: CGFloat,
    masterRatio: CGFloat,
    placement: MasterPlacement
  ) -> TilingLayoutResult {
    let availableWidth = bounds.width - gap
    guard availableWidth >= 0 else { return .insufficientSpace(.horizontalGap) }

    let masterWidth = (availableWidth * masterRatio).rounded()
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
        length: bounds.height,
        count: stackWindowIDs.count,
        gap: gap,
        minimum: Self.minimumWindowSize.height
      )
    else {
      return .insufficientSpace(.stackHeight)
    }

    let masterX = placement == .left ? bounds.minX : bounds.maxX - masterWidth
    let stackX = placement == .left ? masterX + masterWidth + gap : bounds.minX
    var framesByWindowID = [
      windowIDs[0]: CGRect(
        x: masterX,
        y: bounds.minY,
        width: masterWidth,
        height: bounds.height
      )
    ]
    var stackY = bounds.minY
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

  /// Arrange a master row and horizontal stack on the top or bottom.
  private func rowLayout(
    windowIDs: [CGWindowID],
    in bounds: CGRect,
    gap: CGFloat,
    masterRatio: CGFloat,
    placement: MasterPlacement
  ) -> TilingLayoutResult {
    let availableHeight = bounds.height - gap
    guard availableHeight >= 0 else { return .insufficientSpace(.verticalGap) }

    let masterHeight = (availableHeight * masterRatio).rounded()
    let stackHeight = availableHeight - masterHeight
    guard masterHeight >= Self.minimumWindowSize.height else {
      return .insufficientSpace(.masterHeight)
    }
    guard stackHeight >= Self.minimumWindowSize.height else {
      return .insufficientSpace(.stackHeight)
    }

    let stackWindowIDs = Array(windowIDs.dropFirst())
    guard
      let stackWidths = partitions(
        length: bounds.width,
        count: stackWindowIDs.count,
        gap: gap,
        minimum: Self.minimumWindowSize.width
      )
    else {
      return .insufficientSpace(.stackWidth)
    }

    let masterY = placement == .top ? bounds.minY : bounds.maxY - masterHeight
    let stackY = placement == .top ? masterY + masterHeight + gap : bounds.minY
    var framesByWindowID = [
      windowIDs[0]: CGRect(
        x: bounds.minX,
        y: masterY,
        width: bounds.width,
        height: masterHeight
      )
    ]
    var stackX = bounds.minX
    for (index, windowID) in stackWindowIDs.enumerated() {
      let width = stackWidths[index]
      framesByWindowID[windowID] = CGRect(
        x: stackX,
        y: stackY,
        width: width,
        height: stackHeight
      )
      stackX += width + gap
    }
    return .frames(framesByWindowID)
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
}
