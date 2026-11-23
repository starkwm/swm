import CoreGraphics

public typealias LayoutRatioChange = NumericChange<CGFloat>

extension LayoutRatioChange {
  func applying(to currentRatio: CGFloat) -> CGFloat {
    switch self {
    case .absolute(let ratio): TilingLimits.clampedRatio(ratio)
    case .relative(let delta): TilingLimits.clampedRatio(currentRatio + delta)
    }
  }
}
