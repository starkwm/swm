/// Runtime model for a WindowServer space.
struct Space: Equatable, Sendable, CustomStringConvertible {
  /// WindowServer space ID.
  let id: UInt64

  /// WindowServer space type.
  let type: SpaceType

  /// Debug description including space ID and type.
  var description: String {
    "<Space id: \(id), type: \(type)>"
  }

  /// Create a space model by looking up its current WindowServer type.
  init(id: UInt64) {
    self.id = id
    type = WindowServerClient.shared.spaceType(for: id)
  }

  /// Create a space model from explicit fields.
  init(id: UInt64, type: SpaceType) {
    self.id = id
    self.type = type
  }

  /// Compare spaces by their stable WindowServer ID.
  static func == (lhs: Space, rhs: Space) -> Bool {
    lhs.id == rhs.id
  }
}
