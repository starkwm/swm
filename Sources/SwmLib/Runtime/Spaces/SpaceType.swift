/// WindowServer space type.
enum SpaceType: Int32 {
  /// Standard desktop space.
  case normal = 0

  /// Native fullscreen app space.
  case fullscreen = 4

  /// Space type not recognized by swm.
  case unknown
}

extension SpaceType: CustomStringConvertible {
  /// Human-readable space type.
  var description: String {
    switch self {
    case .normal:
      return "normal"
    case .fullscreen:
      return "fullscreen"
    case .unknown:
      return "unknown"
    }
  }
}
