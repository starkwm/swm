import Foundation

/// Timing curves shared by the command-line parser and frame animator.
public enum AnimationEasing: String, CaseIterable, Sendable {
  case linear
  case easeOutQuad = "ease-out-quad"
  case easeOutCubic = "ease-out-cubic"
  case easeOutCirc = "ease-out-circ"
  case easeInOutQuad = "ease-in-out-quad"

  func value(at progress: Double) -> Double {
    let t = min(1, max(0, progress))
    switch self {
    case .linear: return t
    case .easeOutQuad: return 1 - (1 - t) * (1 - t)
    case .easeOutCubic: return 1 - pow(1 - t, 3)
    case .easeOutCirc: return sqrt(1 - (t - 1) * (t - 1))
    case .easeInOutQuad: return t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }
  }
}
