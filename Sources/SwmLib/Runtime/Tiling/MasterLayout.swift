import CoreGraphics

/// Pure ordered master layout geometry calculator.
struct MasterLayout {
  /// Calculate master layout frames, or nil when the bounds cannot fit every window.
  func layout(
    windowIDs: [CGWindowID],
    in bounds: CGRect,
    settings: SpaceSettings,
    masterRatio: CGFloat = 0.5,
    placement: MasterPlacement = .left
  ) -> [CGWindowID: CGRect]? {
    guard !windowIDs.isEmpty else { return [:] }
    guard let usableBounds = settings.usableTilingBounds(in: bounds) else { return nil }
    guard windowIDs.count > 1 else { return [windowIDs[0]: usableBounds] }

    // Rows are laid out as columns in transposed space, then transposed back.
    let transposed = placement == .top || placement == .bottom
    return stackLayout(
      windowIDs: windowIDs,
      in: transposed ? usableBounds.transposed : usableBounds,
      gap: settings.tilingGap,
      masterRatio: TilingLimits.clampedRatio(masterRatio),
      masterFirst: placement == .left || placement == .top,
      transposed: transposed
    )
  }

  /// Arrange a master column and a vertical stack beside it.
  ///
  /// With `transposed`, the bounds are a master row and horizontal stack with their axes
  /// swapped, and the frames are swapped back.
  private func stackLayout(
    windowIDs: [CGWindowID],
    in bounds: CGRect,
    gap: CGFloat,
    masterRatio: CGFloat,
    masterFirst: Bool,
    transposed: Bool
  ) -> [CGWindowID: CGRect]? {
    let minimum = TilingLimits.minimumWindowLength
    let available = bounds.width - gap
    let masterLength = (available * masterRatio).rounded()
    let stackLength = available - masterLength
    guard masterLength >= minimum, stackLength >= minimum else { return nil }

    let stackWindowIDs = Array(windowIDs.dropFirst())
    guard
      let stackLengths = partitions(
        length: bounds.height,
        count: stackWindowIDs.count,
        gap: gap,
        minimum: minimum
      )
    else { return nil }

    let masterX = masterFirst ? bounds.minX : bounds.maxX - masterLength
    let stackX = masterFirst ? masterX + masterLength + gap : bounds.minX
    var frames = [
      windowIDs[0]: CGRect(
        x: masterX,
        y: bounds.minY,
        width: masterLength,
        height: bounds.height
      )
    ]
    var stackY = bounds.minY
    for (index, windowID) in stackWindowIDs.enumerated() {
      let length = stackLengths[index]
      frames[windowID] = CGRect(x: stackX, y: stackY, width: stackLength, height: length)
      stackY += length + gap
    }

    return transposed ? frames.mapValues(\.transposed) : frames
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

extension CGRect {
  /// The rectangle with its x and y axes swapped.
  fileprivate var transposed: CGRect {
    CGRect(x: minY, y: minX, width: height, height: width)
  }
}
