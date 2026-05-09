import AppKit

/// Runtime model for a WindowServer space.
final class Space: NSObject {
  /// WindowServer space ID.
  var id: UInt64

  /// WindowServer space type.
  var type: SpaceType

  /// Debug description including space ID and type.
  override var description: String {
    "<Space id: \(id), type: \(type)>"
  }

  /// Create a space model by looking up its current WindowServer type.
  convenience init(id: UInt64) {
    self.init(
      id: id,
      type: WindowServerClient.shared.spaceType(for: id)
    )
  }

  /// Create a space model from explicit fields.
  init(id: UInt64, type: SpaceType) {
    self.id = id
    self.type = type
  }

  /// Compare spaces by WindowServer ID.
  override func isEqual(_ object: Any?) -> Bool {
    guard let space = object as? Self else { return false }
    return id == space.id
  }
}

extension Space: @unchecked Sendable {}
