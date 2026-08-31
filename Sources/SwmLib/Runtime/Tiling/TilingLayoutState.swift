import CoreGraphics

/// Runtime automatic-tiling state retained for one Space and physical display.
struct TilingLayoutState {
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
