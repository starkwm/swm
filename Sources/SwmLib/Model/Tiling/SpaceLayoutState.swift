import CoreGraphics

/// Runtime automatic-tiling state retained independently for one Space.
struct SpaceLayoutState: Equatable {
  /// WindowServer display identifier currently owning the Space.
  var displayID: String

  /// Selected layout algorithm.
  var mode: LayoutMode

  /// Ordered retained window leaves.
  var layout: OrderedWindowLayout

  /// Retained leaves omitted from current geometry.
  var minimizedWindowIDs: Set<CGWindowID>

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
