import CoreGraphics

/// Pure monocle layout geometry calculator.
struct MonocleLayout {
  /// Minimum frame size accepted for every tiled window.
  private static let minimumWindowSize = CGSize(width: 1, height: 1)

  /// Give every tiled window the complete padded visible bounds.
  func layout(
    windowIDs: [CGWindowID],
    in bounds: CGRect,
    settings: SpaceSettings
  ) -> TilingLayoutResult {
    guard !windowIDs.isEmpty else { return .frames([:]) }

    let usableBounds = settings.tilingBounds(in: bounds)
    guard usableBounds.size.meetsTilingMinimum(Self.minimumWindowSize) else {
      return .insufficientSpace(.usableBounds)
    }

    return .frames(Dictionary(uniqueKeysWithValues: windowIDs.map { ($0, usableBounds) }))
  }
}
