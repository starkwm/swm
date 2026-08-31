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
  @MainActor
  static func all(snapshot: QuerySnapshot) -> [SpaceSerializer] {
    var screenIDsBySpaceID = [UInt64: [String]]()
    var windowIDsBySpaceID = [UInt64: [CGWindowID]]()

    for display in snapshot.displaySpaces {
      for spaceID in display.spaces {
        screenIDsBySpaceID[spaceID, default: []].append(display.id)
      }
    }

    for window in snapshot.windows {
      for spaceID in snapshot.spaceIDsByWindowID[window.id] ?? [] {
        windowIDsBySpaceID[spaceID, default: []].append(window.id)
      }
    }

    return snapshot.spaces.enumerated().map { index, space in
      let screenIDs = screenIDsBySpaceID[space.id] ?? []
      let normalizedScreenIDSet = Set(screenIDs.map { $0.lowercased() })
      let directlyResolvedScreens = snapshot.arrangedScreens.filter {
        normalizedScreenIDSet.contains($0.uuid.lowercased())
      }
      let hasSharedDisplaySpaces = normalizedScreenIDSet.contains("main")
      let resolvedScreens =
        hasSharedDisplaySpaces
        ? snapshot.arrangedScreens
        : directlyResolvedScreens
      let visibleScreenIDs =
        hasSharedDisplaySpaces
        ? Set(snapshot.arrangedScreens.map(\.uuid))
        : Set(screenIDs)

      return SpaceSerializer(
        id: space.id,
        index: index,
        type: space.type.description,
        displays: resolvedScreens.compactMap(\.id),
        windows: windowIDsBySpaceID[space.id] ?? [],
        hasFocus: space.id == snapshot.activeSpaceID,
        isVisible: visibleScreenIDs.contains { screenID in
          snapshot.currentSpaceByScreenID[screenID] == space.id
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
