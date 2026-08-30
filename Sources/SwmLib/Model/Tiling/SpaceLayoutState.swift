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
  /// Selected layout algorithm.
  var mode: LayoutMode

  /// Persistent sibling relationships and stable window order.
  var tree: TilingTree?
  /// Retained minimized, unresolved, or native-fullscreen leaves omitted from current geometry.
  var omittedWindowIDs: Set<CGWindowID>

  /// Last focused tiled window used as the insertion anchor.
  var focusedWindowID: CGWindowID?

  /// Whether automatic frame planning is enabled for this Space.
  var enabled: Bool
}

/// Automatic layout algorithms supported by runtime state.
enum LayoutMode: String, Equatable {
  /// One master pane with remaining windows in a vertical stack.
  case master

  /// Recursively bisect the longest edge of the remaining region.
  case dwindle
}
