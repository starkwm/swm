import AppKit

/// Lazy raw-state snapshot shared by display, space, and window query serializers.
final class QuerySnapshot {
  private let windowManager: WindowManager

  lazy var activeSpaceID = SpaceManager.active().id
  lazy var arrangedScreens = NSScreen.arrangedScreens
  lazy var displaySpaces = WindowServerClient.shared.displaySpaces()
  lazy var screens = NSScreen.screens
  lazy var spaces = SpaceManager.all()
  lazy var windows = windowManager.allWindows()

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

  init(windowManager: WindowManager) {
    self.windowManager = windowManager
  }
}
