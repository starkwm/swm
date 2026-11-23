public enum MasterPlacement: String, Equatable, CaseIterable, Codable, Sendable {
  case left

  case right

  case top

  case bottom

  func cycled(in direction: CycleDirection) -> MasterPlacement {
    switch (self, direction) {
    case (.left, .next), (.right, .prev):
      return .top
    case (.top, .next), (.bottom, .prev):
      return .right
    case (.right, .next), (.left, .prev):
      return .bottom
    case (.bottom, .next), (.top, .prev):
      return .left
    }
  }
}
