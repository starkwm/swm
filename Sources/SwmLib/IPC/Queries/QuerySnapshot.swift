import AppKit
import StarkSkyLight

/// Lazy raw-state snapshot shared by display, space, and window query serializers.
@MainActor
final class QuerySnapshot {
  /// Index Core Graphics metadata by window ID for constant-time lookup.
  static func indexWindowInfo(_ windowInfo: [[String: Any]]) -> [CGWindowID: [String: Any]] {
    windowInfo.reduce(into: [:]) { result, info in
      guard let windowID = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value else {
        return
      }

      result[windowID] = info
    }
  }

  lazy var focusedWindowID = focusProvider()
  lazy var spaceSnapshot = WindowServerClient.shared.spaceSnapshotIfAvailable()
  lazy var activeSpaceID = spaceSnapshot?.activeSpaceID?.rawValue
  lazy var arrangedScreens = NSScreen.arrangedScreens
  lazy var screens = NSScreen.screens
  lazy var spaces = Spaces.all(in: spaceSnapshot)
  lazy var windows = managedWindows.allWindows()

  /// Space IDs keyed by WindowServer display identifier, which may be "Main".
  lazy var displaySpaces: [String: [UInt64]] = Dictionary(
    uniqueKeysWithValues: (spaceSnapshot?.displays ?? []).map {
      ($0.id.rawValue, $0.spaces.map(\.id.rawValue))
    }
  )

  /// Current Spaces keyed by display identifier and by screen UUID.
  ///
  /// Without separate Spaces, every screen shows WindowServer's Main display Space.
  lazy var currentSpaceByScreenID: [String: UInt64] = {
    let displays = spaceSnapshot?.displays ?? []
    let currentByID = Dictionary(
      uniqueKeysWithValues: displays.map { ($0.id.rawValue.lowercased(), $0.currentSpaceID) }
    )
    let screenIDs = Set(displays.map(\.id.rawValue) + arrangedScreens.map(\.uuid))
    return Dictionary(
      uniqueKeysWithValues: screenIDs.compactMap { screenID in
        guard let current = currentByID[screenID.lowercased()] ?? currentByID["main"], let current
        else { return nil }
        return (screenID, current.rawValue)
      }
    )
  }()

  lazy var nativeFullscreenSpaceIDs = Set(
    spaces.lazy.filter { $0.type == .fullscreen }.map(\.id)
  )

  lazy var spaceIDsByWindowID: [CGWindowID: [UInt64]] = Dictionary(
    uniqueKeysWithValues: windows.map { window in
      (window.id, WindowServerClient.shared.spaceIDs(containing: window.id))
    }
  )

  lazy var spaceIndexByID = Dictionary(
    uniqueKeysWithValues: spaces.enumerated().map { ($0.element.id, $0.offset + 1) }
  )

  lazy var windowInfoByID: [CGWindowID: [String: Any]] = {
    let windowInfo =
      CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
    return Self.indexWindowInfo(windowInfo)
  }()

  private let managedWindows: Windows
  private let focusProvider: () -> CGWindowID?

  init(windows: Windows, focusedWindowID: @escaping () -> CGWindowID? = Windows.focusedWindowID) {
    managedWindows = windows
    focusProvider = focusedWindowID
  }
}
