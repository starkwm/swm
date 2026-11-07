import CoreGraphics

/// Absolute or relative update to a bounded layout ratio.
enum LayoutRatioChange: Equatable {
  /// Replace the current ratio.
  case absolute(CGFloat)

  /// Add a delta to the current ratio.
  case relative(CGFloat)

  /// Apply the update and clamp it to a useful tiled range.
  func applying(to currentRatio: CGFloat) -> CGFloat {
    let updatedRatio: CGFloat
    switch self {
    case .absolute(let ratio):
      updatedRatio = ratio
    case .relative(let delta):
      updatedRatio = currentRatio + delta
    }
    return TilingLimits.clampedRatio(updatedRatio)
  }
}
