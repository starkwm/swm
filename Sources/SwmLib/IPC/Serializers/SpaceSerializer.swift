import Foundation

struct SpaceSerializer: Encodable, Equatable {
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

  static func all(windowManager: WindowManager) -> [SpaceSerializer] {
    let spaces = SpaceManager.all()
    let activeSpaceID = SpaceManager.active().id
    let displaySpaces = WindowServerClient.shared.displaySpaces()
    let windows = windowManager.allWindows()

    return spaces.enumerated().map { index, space in
      let display = displaySpaces.first { $0.spaces.contains(space.id) }?.id
      let windowIDs =
        windows
        .filter { window in
          WindowServerClient.shared.spaceIDs(containing: window.id)
            .contains(space.id)
        }
        .map(\.id)

      return SpaceSerializer(
        id: space.id,
        index: index,
        type: space.type.description,
        display: display,
        windows: windowIDs,
        hasFocus: space.id == activeSpaceID,
        isVisible: display.map { screenID in
          WindowServerClient.shared.currentSpace(screenID: screenID) == space.id
        } ?? false,
        isNativeFullscreen: space.type == .fullscreen
      )
    }
  }

  let id: UInt64
  let index: Int
  let type: String
  let display: String?
  let windows: [UInt32]
  let hasFocus: Bool
  let isVisible: Bool
  let isNativeFullscreen: Bool

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(index, forKey: .index)
    try container.encode(type, forKey: .type)
    try container.encodeNilOrValue(display, forKey: .display)
    try container.encode(windows, forKey: .windows)
    try container.encode(hasFocus, forKey: .hasFocus)
    try container.encode(isVisible, forKey: .isVisible)
    try container.encode(isNativeFullscreen, forKey: .isNativeFullscreen)
  }
}
