import CoreGraphics

/// Limits shared by the automatic-tiling layouts.
enum TilingLimits {
  /// Minimum frame size accepted for every tiled window.
  static let minimumWindowSize = CGSize(width: 1, height: 1)

  /// Range of useful master and split ratios.
  static let ratioRange: ClosedRange<CGFloat> = 0.1...0.9

  /// Clamp a master or split ratio to the useful range.
  static func clampedRatio(_ ratio: CGFloat) -> CGFloat {
    min(max(ratio, ratioRange.lowerBound), ratioRange.upperBound)
  }
}

extension CGSize {
  /// Return whether both dimensions meet a minimum tile size.
  func meetsTilingMinimum(_ minimum: CGSize) -> Bool {
    width >= minimum.width && height >= minimum.height
  }
}

extension SpaceSettings {
  /// Effective gap between adjacent tiled windows.
  var tilingGap: CGFloat {
    CGFloat(max(0, gap))
  }

  /// Padded bounds for tiling, or nil when they cannot fit a minimum-size window.
  func usableTilingBounds(in bounds: CGRect) -> CGRect? {
    let usableBounds = tilingBounds(in: bounds)
    return usableBounds.size.meetsTilingMinimum(TilingLimits.minimumWindowSize)
      ? usableBounds : nil
  }

  /// Visible bounds after applying per-Space padding.
  func tilingBounds(in bounds: CGRect) -> CGRect {
    let top = CGFloat(max(0, padding.top))
    let bottom = CGFloat(max(0, padding.bottom))
    let left = CGFloat(max(0, padding.left))
    let right = CGFloat(max(0, padding.right))

    return CGRect(
      x: bounds.minX + left,
      y: bounds.minY + top,
      width: max(0, bounds.width - left - right),
      height: max(0, bounds.height - top - bottom)
    )
  }
}
