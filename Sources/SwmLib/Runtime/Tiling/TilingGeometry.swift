import CoreGraphics

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
