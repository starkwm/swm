import CoreGraphics

/// Pure monocle layout geometry calculator.
struct MonocleLayout {
  /// Give every tiled window the complete padded visible bounds.
  func layout(
    windowIDs: [CGWindowID],
    in bounds: CGRect,
    settings: SpaceSettings
  ) -> TilingLayoutResult {
    guard !windowIDs.isEmpty else { return .frames([:]) }

    guard let usableBounds = settings.usableTilingBounds(in: bounds) else {
      return .insufficientSpace(.usableBounds)
    }

    return .frames(Dictionary(uniqueKeysWithValues: windowIDs.map { ($0, usableBounds) }))
  }
}
