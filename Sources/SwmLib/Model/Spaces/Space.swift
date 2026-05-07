import AppKit

final class Space: NSObject {
  override var description: String {
    "<Space id: \(id), type: \(type)>"
  }

  var id: UInt64
  var type: SpaceType

  convenience init(id: UInt64) {
    self.init(
      id: id,
      type: WindowServerClient.shared.spaceType(for: id)
    )
  }

  init(id: UInt64, type: SpaceType) {
    self.id = id
    self.type = type
  }

  override func isEqual(_ object: Any?) -> Bool {
    guard let space = object as? Self else { return false }
    return id == space.id
  }
}

extension Space: @unchecked Sendable {}
