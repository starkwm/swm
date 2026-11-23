import CoreGraphics

struct MasterLayout {
  func layout(
    windowIDs: [CGWindowID],
    in bounds: CGRect,
    settings: SpaceSettings,
    masterRatio: CGFloat = 0.5,
    placement: MasterPlacement = .left,
    minimumSizes: [CGWindowID: CGSize] = [:]
  ) -> [CGWindowID: CGRect]? {
    guard !windowIDs.isEmpty else { return [:] }
    guard let usableBounds = settings.usableTilingBounds(in: bounds) else { return nil }
    guard windowIDs.count > 1 else { return [windowIDs[0]: usableBounds] }

    let transposed = placement == .top || placement == .bottom
    return stackLayout(
      windowIDs: windowIDs,
      in: transposed ? usableBounds.transposed : usableBounds,
      gap: settings.tilingGap,
      masterRatio: TilingLimits.clampedRatio(masterRatio),
      masterFirst: placement == .left || placement == .top,
      transposed: transposed,
      minimumSizes: transposed ? minimumSizes.mapValues(\.transposed) : minimumSizes
    )
  }

  private func stackLayout(
    windowIDs: [CGWindowID],
    in bounds: CGRect,
    gap: CGFloat,
    masterRatio: CGFloat,
    masterFirst: Bool,
    transposed: Bool,
    minimumSizes: [CGWindowID: CGSize]
  ) -> [CGWindowID: CGRect]? {
    let minimum = TilingLimits.minimumWindowLength
    let stackWindowIDs = Array(windowIDs.dropFirst())
    let available = bounds.width - gap
    let masterLength = TilingLimits.allocation(
      (available * masterRatio).rounded(),
      of: available,
      firstMinimum: minimumSizes[windowIDs[0]]?.width ?? 0,
      secondMinimum: stackWindowIDs.map { minimumSizes[$0]?.width ?? 0 }.max() ?? 0
    )
    let stackLength = available - masterLength
    guard masterLength >= minimum, stackLength >= minimum else { return nil }

    guard
      let stackLengths = partitions(
        length: bounds.height,
        minimumLengths: stackWindowIDs.map { minimumSizes[$0]?.height ?? 0 },
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

  private func partitions(
    length: CGFloat,
    minimumLengths: [CGFloat],
    gap: CGFloat,
    minimum: CGFloat
  ) -> [CGFloat]? {
    let count = minimumLengths.count
    guard count > 0 else { return [] }

    let availableLength = length - gap * CGFloat(count - 1)
    guard availableLength >= 0 else { return nil }

    var lengths = (0..<count).map { index in
      let start = (availableLength * CGFloat(index) / CGFloat(count)).rounded()
      let end = (availableLength * CGFloat(index + 1) / CGFloat(count)).rounded()
      return end - start
    }
    if minimumLengths.reduce(0, +) <= availableLength {
      lengths = raising(lengths, to: minimumLengths)
    }

    return lengths.allSatisfy { $0 >= minimum } ? lengths : nil
  }

  /// Grows lengths below their minimum, taking the space from the others in proportion
  /// to how much each has above its own minimum. The total stays the same.
  private func raising(_ lengths: [CGFloat], to minimumLengths: [CGFloat]) -> [CGFloat] {
    let shortfall = zip(lengths, minimumLengths).map { max(0, $1 - $0) }.reduce(0, +)
    guard shortfall > 0 else { return lengths }

    let spares = zip(lengths, minimumLengths).map { max(0, $0 - $1) }
    let totalSpare = spares.reduce(0, +)
    var raised = lengths.indices.map { index in
      lengths[index] < minimumLengths[index]
        ? minimumLengths[index]
        : lengths[index] - (shortfall * spares[index] / totalSpare).rounded()
    }
    if let donor = spares.indices.last(where: { spares[$0] > 0 }) {
      raised[donor] += lengths.reduce(0, +) - raised.reduce(0, +)
    }
    return raised
  }
}

extension CGRect {
  fileprivate var transposed: CGRect {
    CGRect(x: minY, y: minX, width: height, height: width)
  }
}

extension CGSize {
  fileprivate var transposed: CGSize {
    CGSize(width: height, height: width)
  }
}
