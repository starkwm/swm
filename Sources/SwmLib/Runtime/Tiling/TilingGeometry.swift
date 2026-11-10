import CoreGraphics

/// Limits shared by the automatic-tiling layouts.
enum TilingLimits {
  /// Minimum width and height accepted for every tiled window.
  static let minimumWindowLength: CGFloat = 1

  /// Range of useful master and split ratios.
  static let ratioRange: ClosedRange<CGFloat> = 0.1...0.9

  /// Clamp a master or split ratio to the useful range.
  static func clampedRatio(_ ratio: CGFloat) -> CGFloat {
    min(max(ratio, ratioRange.lowerBound), ratioRange.upperBound)
  }
}

extension CGSize {
  /// Whether both dimensions meet the minimum tile length.
  var meetsTilingMinimum: Bool {
    width >= TilingLimits.minimumWindowLength && height >= TilingLimits.minimumWindowLength
  }
}

extension SpaceSettings {
  /// Gap between adjacent tiled windows; writers store it clamped to zero or greater.
  var tilingGap: CGFloat { CGFloat(gap) }

  /// Padded bounds for tiling, or nil when they cannot fit a minimum-size window.
  func usableTilingBounds(in bounds: CGRect) -> CGRect? {
    let usableBounds = tilingBounds(in: bounds)
    return usableBounds.size.meetsTilingMinimum ? usableBounds : nil
  }

  /// Visible bounds after applying per-Space padding, which writers store clamped.
  func tilingBounds(in bounds: CGRect) -> CGRect {
    let (top, bottom) = (CGFloat(padding.top), CGFloat(padding.bottom))
    let (left, right) = (CGFloat(padding.left), CGFloat(padding.right))

    return CGRect(
      x: bounds.minX + left,
      y: bounds.minY + top,
      width: max(0, bounds.width - left - right),
      height: max(0, bounds.height - top - bottom)
    )
  }
}
