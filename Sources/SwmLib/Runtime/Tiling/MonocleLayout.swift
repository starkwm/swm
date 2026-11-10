import CoreGraphics

/// Pure monocle layout geometry calculator.
struct MonocleLayout {
  /// Give every tiled window the complete padded visible bounds, or nil when they are too small.
  func layout(
    windowIDs: [CGWindowID],
    in bounds: CGRect,
    settings: SpaceSettings
  ) -> [CGWindowID: CGRect]? {
    guard !windowIDs.isEmpty else { return [:] }
    guard let usableBounds = settings.usableTilingBounds(in: bounds) else { return nil }

    return Dictionary(uniqueKeysWithValues: windowIDs.map { ($0, usableBounds) })
  }
}
