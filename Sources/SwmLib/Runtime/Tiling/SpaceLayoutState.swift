import CoreGraphics

/// Runtime automatic-tiling state retained for one Space and physical display.
struct SpaceLayoutState {
  /// Selected floating or automatic layout.
  var selection: LayoutSelection

  /// Fraction of the Space assigned to the master pane.
  var masterRatio: CGFloat

  /// Edge occupied by the master pane.
  var masterPlacement: MasterPlacement

  /// Whether dwindle branches retain their initially resolved split direction.
  var preserveSplitDirections: Bool

  /// Persistent sibling relationships and stable window order.
  var tree: TilingTree?
  /// Retained minimized, unresolved, or native-fullscreen leaves omitted from current geometry.
  var omittedWindowIDs: Set<CGWindowID>

  /// Last focused tiled window used as the insertion anchor.
  var focusedWindowID: CGWindowID?
}

/// Identifies one independently tiled display within a macOS Space.
struct SpaceLayoutID: Hashable {
  /// WindowServer Space ID.
  let spaceID: UInt64

  /// Core Graphics display UUID.
  let displayID: String
}

/// Edge occupied by the master pane in the master layout.
enum MasterPlacement: String, Equatable {
  /// Master column on the leading horizontal edge.
  case left

  /// Master column on the trailing horizontal edge.
  case right

  /// Master row on the upper edge.
  case top

  /// Master row on the lower edge.
  case bottom
}

/// Absolute or relative update to a bounded layout ratio.
enum LayoutRatioChange: Equatable {
  /// Replace the current ratio.
  case absolute(CGFloat)

  /// Add a delta to the current ratio.
  case relative(CGFloat)

  /// Apply the update and clamp it to a useful tiled range.
  func applying(to currentRatio: CGFloat) -> CGFloat {
    let updatedRatio: CGFloat
    switch self {
    case .absolute(let ratio):
      updatedRatio = ratio
    case .relative(let delta):
      updatedRatio = currentRatio + delta
    }
    return min(max(updatedRatio, 0.1), 0.9)
  }
}

/// User-facing automatic layout selection, including unmanaged floating windows.
enum LayoutSelection: String, Equatable {
  /// Leave windows unmanaged by automatic tiling.
  case float

  /// Arrange windows as one master pane and a stack.
  case master

  /// Recursively bisect the longest edge of the remaining region.
  case dwindle
}

/// Per-window participation in an automatic Space layout.
enum WindowLayoutSelection: String, Equatable {
  /// Remove the window from automatic layout geometry.
  case float

  /// Return the window to automatic layout geometry.
  case tile
}
