import AppKit

struct SpaceSerializer: Encodable, Equatable {
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

  @MainActor
  static func all(snapshot: QuerySnapshot) -> [SpaceSerializer] {
    var screenIDsBySpaceID = [UInt64: [String]]()
    var windowIDsBySpaceID = [UInt64: [CGWindowID]]()

    for (displayID, spaceIDs) in snapshot.displaySpaces {
      for spaceID in spaceIDs {
        screenIDsBySpaceID[spaceID, default: []].append(displayID)
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
        index: index + 1,
        type: space.type.rawValue,
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

  let id: UInt64

  let index: Int

  let type: String

  let displays: [UInt32]

  let windows: [UInt32]

  let hasFocus: Bool

  let isVisible: Bool

  let isNativeFullscreen: Bool
}
