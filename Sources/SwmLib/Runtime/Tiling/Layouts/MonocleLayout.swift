import CoreGraphics

struct MonocleLayout {
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
