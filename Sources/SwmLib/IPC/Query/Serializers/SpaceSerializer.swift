import Foundation

struct SpaceSerializer: Encodable, Equatable {
  let id: UInt64
  let uuid: String?
  let index: Int
  let label: String?
  let type: String
  let display: String?
  let windows: [UInt32]
  let hasFocus: Bool
  let isVisible: Bool
  let isNativeFullscreen: Bool

  enum CodingKeys: String, CodingKey {
    case id
    case uuid
    case index
    case label
    case type
    case display
    case windows
    case hasFocus = "has-focus"
    case isVisible = "is-visible"
    case isNativeFullscreen = "is-native-fullscreen"
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encodeNilOrValue(uuid, forKey: .uuid)
    try container.encode(index, forKey: .index)
    try container.encodeNilOrValue(label, forKey: .label)
    try container.encode(type, forKey: .type)
    try container.encodeNilOrValue(display, forKey: .display)
    try container.encode(windows, forKey: .windows)
    try container.encode(hasFocus, forKey: .hasFocus)
    try container.encode(isVisible, forKey: .isVisible)
    try container.encode(isNativeFullscreen, forKey: .isNativeFullscreen)
  }
}

extension SpaceSerializer {
  static func all(windowManager: WindowManager) -> [SpaceSerializer] {
    let spaces = Space.all()
    let activeSpaceID = Space.active().id
    let displaySpaces = WindowServerClient.shared.displaySpaces(connectionID: Space.connection)
    let windows = windowManager.allWindows()

    return spaces.enumerated().map { index, space in
      let display = displaySpaces.first { $0.spaces.contains(space.id) }?.id
      let windowIDs =
        windows
        .filter { window in
          WindowServerClient.shared.spaceIDs(containing: window.id, connectionID: Space.connection)
            .contains(space.id)
        }
        .map(\.id)

      return SpaceSerializer(
        id: space.id,
        uuid: nil,
        index: index,
        label: nil,
        type: space.type.description,
        display: display,
        windows: windowIDs,
        hasFocus: space.id == activeSpaceID,
        isVisible: display.map { screenID in
          WindowServerClient.shared.currentSpace(connectionID: Space.connection, screenID: screenID)
            == space.id
        } ?? false,
        isNativeFullscreen: space.type == .fullscreen
      )
    }
  }
}
