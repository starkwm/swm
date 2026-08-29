import CoreGraphics

/// Identifies one independently tiled display within a macOS Space.
struct SpaceLayoutID: Hashable {
  /// WindowServer Space ID.
  let spaceID: UInt64

  /// Core Graphics display UUID.
  let displayID: String
}

/// Runtime automatic-tiling state retained for one Space and physical display.
struct SpaceLayoutState {
  /// Selected floating or automatic layout.
  var selection: LayoutSelection

  /// Persistent sibling relationships and stable window order.
  var tree: TilingTree?
  /// Retained minimized, unresolved, or native-fullscreen leaves omitted from current geometry.
  var omittedWindowIDs: Set<CGWindowID>

  /// Last focused tiled window used as the insertion anchor.
  var focusedWindowID: CGWindowID?

}

/// User-facing automatic layout selection, including unmanaged floating windows.
enum LayoutSelection: String, Equatable {
  /// Leave windows unmanaged by automatic tiling.
  case float

  /// Arrange windows as one master pane and a vertical stack.
  case master

  /// Recursively bisect the longest edge of the remaining region.
  case dwindle
}
