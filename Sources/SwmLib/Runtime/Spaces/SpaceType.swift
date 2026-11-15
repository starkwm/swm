import StarkSkyLight

enum SpaceType: String {
  case normal

  case fullscreen

  case unknown

  init(_ type: StarkSkyLight.SpaceType) {
    switch type {
    case .desktop: self = .normal
    case .fullscreen: self = .fullscreen
    case .unknown: self = .unknown
    }
  }
}
