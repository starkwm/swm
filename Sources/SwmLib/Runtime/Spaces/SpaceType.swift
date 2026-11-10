import StarkSkyLight

/// WindowServer space type.
///
/// Raw values are the type names reported by queries.
enum SpaceType: String {
  /// Standard desktop space.
  case normal

  /// Native fullscreen app space.
  case fullscreen

  /// Space type not recognized by swm.
  case unknown

  init(_ type: StarkSkyLight.SpaceType) {
    switch type {
    case .desktop: self = .normal
    case .fullscreen: self = .fullscreen
    case .unknown: self = .unknown
    }
  }
}
