import AppKit

public final class Space: NSObject {
  static let connection = windowServerClient.mainConnectionID()

  private static let windowServerClient = WindowServerClient.shared

  public static func all() -> [Space] {
    windowServerClient.allSpaceIDs(connectionID: connection).map(Space.init(id:))
  }

  public static func active() -> Space {
    Space(id: windowServerClient.activeSpace(connectionID: connection))
  }

  public override var description: String {
    "<Space id: \(id), type: \(type)>"
  }

  var id: UInt64

  private var type: SpaceType

  public convenience init(id: UInt64) {
    self.init(
      id: id,
      type: Self.windowServerClient.spaceType(connectionID: Space.connection, spaceID: id)
    )
  }

  init(id: UInt64, type: SpaceType) {
    self.id = id
    self.type = type
  }

  public override func isEqual(_ object: Any?) -> Bool {
    guard let space = object as? Self else { return false }
    return id == space.id
  }

}
