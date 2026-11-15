struct Space: Equatable, Sendable, CustomStringConvertible {
  let id: UInt64

  let type: SpaceType

  var description: String {
    "<Space id: \(id), type: \(type)>"
  }

  @MainActor
  init(id: UInt64) {
    self.id = id
    type = WindowServerClient.shared.spaceType(for: id)
  }

  init(id: UInt64, type: SpaceType) {
    self.id = id
    self.type = type
  }

  static func == (lhs: Space, rhs: Space) -> Bool {
    lhs.id == rhs.id
  }
}
