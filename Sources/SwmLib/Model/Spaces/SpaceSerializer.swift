import AppKit

/// Space state returned by query commands.
struct SpaceSerializer: Encodable, Equatable {
  /// JSON keys used for space query output.
  enum CodingKeys: String, CodingKey {
    case id
    case index
    case type
    case displays
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
    let arrangedScreens = NSScreen.arrangedScreens
    let windows = windowManager.allWindows()

    return spaces.enumerated().map { index, space in
      let screenIDs =
        displaySpaces
        .filter { $0.spaces.contains(space.id) }
        .map(\.id)
      let normalizedScreenIDSet = Set(screenIDs.map { $0.lowercased() })
      let directlyResolvedScreens = arrangedScreens.filter {
        normalizedScreenIDSet.contains($0.uuid.lowercased())
      }
      let hasSharedDisplaySpaces = normalizedScreenIDSet.contains("main")
      let resolvedScreens =
        hasSharedDisplaySpaces
        ? arrangedScreens
        : directlyResolvedScreens
      let visibleScreenIDs =
        hasSharedDisplaySpaces
        ? Set(arrangedScreens.map(\.uuid))
        : Set(screenIDs)

      return SpaceSerializer(
        id: space.id,
        index: index,
        type: space.type.description,
        displays: resolvedScreens.compactMap(\.id),
        windows:
          windows
          .filter { window in
            WindowServerClient.shared.spaceIDs(containing: window.id)
              .contains(space.id)
          }
          .map(\.id),
        hasFocus: space.id == activeSpaceID,
        isVisible: visibleScreenIDs.contains { screenID in
          WindowServerClient.shared.currentSpace(for: screenID) == space.id
        },
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

  /// Core Graphics display IDs associated with this space.
  let displays: [UInt32]

  /// Window IDs currently associated with this space.
  let windows: [UInt32]

  /// Whether this space is the active space.
  let hasFocus: Bool

  /// Whether this space is currently visible on its display.
  let isVisible: Bool

  /// Whether this space is a native fullscreen space.
  let isNativeFullscreen: Bool
}
