import AppKit

/// Lazy raw-state snapshot shared by display, space, and window query serializers.
@MainActor
final class QuerySnapshot {
  private let managedWindows: Windows

  lazy var activeSpaceID = Spaces.active().id
  lazy var arrangedScreens = NSScreen.arrangedScreens
  lazy var displaySpaces = WindowServerClient.shared.displaySpaces()
  lazy var screens = NSScreen.screens
  lazy var spaces = Spaces.all()
  lazy var windows = managedWindows.allWindows()

  lazy var currentSpaceByScreenID: [String: UInt64] = {
    let screenIDs = Set(displaySpaces.map(\.id) + arrangedScreens.map(\.uuid))
    return Dictionary(
      uniqueKeysWithValues: screenIDs.map { screenID in
        (screenID, WindowServerClient.shared.currentSpace(for: screenID))
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
    uniqueKeysWithValues: spaces.enumerated().map { ($0.element.id, $0.offset) }
  )

  lazy var windowInfoByID: [CGWindowID: [String: Any]] = {
    let windowInfo =
      CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
    return windowInfo.keyedByWindowID()
  }()

  init(windows: Windows) {
    managedWindows = windows
  }
}
