import CoreGraphics

enum TilingLimits {
  static let minimumWindowLength: CGFloat = 1

  static let ratioRange: ClosedRange<CGFloat> = 0.1...0.9

  static func clampedRatio(_ ratio: CGFloat) -> CGFloat {
    min(max(ratio, ratioRange.lowerBound), ratioRange.upperBound)
  }
}

extension CGSize {
  var meetsTilingMinimum: Bool {
    width >= TilingLimits.minimumWindowLength && height >= TilingLimits.minimumWindowLength
  }
}

extension SpaceSettings {
  var tilingGap: CGFloat { CGFloat(gap) }

  func usableTilingBounds(in bounds: CGRect) -> CGRect? {
    let usableBounds = tilingBounds(in: bounds)
    return usableBounds.size.meetsTilingMinimum ? usableBounds : nil
  }

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
