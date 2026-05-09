import AppKit

/// Serialized space state returned by query IPC commands.
struct SpaceSerializer: Encodable, Equatable {
  /// JSON keys used for space query output.
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

  /// Snapshot all spaces, including their display and window relationships.
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
        display: NSScreen.screen(for: display)?.id,
        windows: windowIDs,
        hasFocus: space.id == activeSpaceID,
        isVisible: display.map { screenID in
          WindowServerClient.shared.currentSpace(for: screenID) == space.id
        } ?? false,
        isNativeFullscreen: space.type == .fullscreen
      )
    }
  }

  /// WindowServer space ID.
  let id: UInt64

  /// Zero-based space index in the current space order.
  let index: Int

  /// Human-readable space type.
  let type: String

  /// Core Graphics display ID for the owning display, when available.
  let display: UInt32?

  /// Window IDs currently associated with this space.
  let windows: [UInt32]

  /// Whether this space is the active space.
  let hasFocus: Bool

  /// Whether this space is currently visible on its display.
  let isVisible: Bool

  /// Whether this space is a native fullscreen space.
  let isNativeFullscreen: Bool

  /// Encode space state using stable query output keys.
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
