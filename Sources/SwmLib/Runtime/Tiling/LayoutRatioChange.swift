import CoreGraphics

/// Absolute or relative update to a bounded layout ratio.
typealias LayoutRatioChange = NumericChange<CGFloat>

extension LayoutRatioChange {
  /// Apply the update and clamp it to a useful tiled range.
  func applying(to currentRatio: CGFloat) -> CGFloat {
    switch self {
    case .absolute(let ratio): TilingLimits.clampedRatio(ratio)
    case .relative(let delta): TilingLimits.clampedRatio(currentRatio + delta)
    }
  }
}
