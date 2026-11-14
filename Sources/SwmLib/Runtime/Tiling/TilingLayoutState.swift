import CoreGraphics

/// Runtime automatic-tiling state retained for one Space and physical display.
struct TilingLayoutState {
  /// Selected floating or automatic layout.
  var selection: LayoutSelection

  /// Fraction of the Space assigned to the master pane.
  var masterRatio: CGFloat

  /// Edge occupied by the master pane.
  var masterPlacement: MasterPlacement

  /// Fraction of each dwindle branch assigned to its first subtree.
  var splitRatio: CGFloat

  /// Whether dwindle branches retain their initially resolved split direction.
  var preserveSplitDirections: Bool

  /// Persistent sibling relationships and stable window order.
  var tree: TilingTree?

  /// Retained minimized, unresolved, or native-fullscreen leaves omitted from current geometry.
  var omittedWindowIDs: Set<CGWindowID>

  /// Last focused tiled window used as the insertion anchor.
  var focusedWindowID: CGWindowID?

  /// The configurable values, without windows or focus.
  var settings: TilingLayoutSettings {
    TilingLayoutSettings(
      selection: selection,
      masterRatio: masterRatio,
      masterPlacement: masterPlacement,
      splitRatio: splitRatio,
      preserveSplitDirections: preserveSplitDirections
    )
  }

  /// Use a dwindle split ratio for new branches and rebalance existing ones to it.
  mutating func setSplitRatio(_ ratio: CGFloat) {
    splitRatio = ratio
    tree = tree?.settingSplitRatios(ratio)
  }

  /// Retain dwindle split directions, or clear those already retained.
  mutating func setPreserveSplitDirections(_ enabled: Bool) {
    preserveSplitDirections = enabled
    if !enabled {
      tree = tree?.clearingSplitDirections()
    }
  }

  /// Restore configurable values, rebalancing or clearing splits only when those values change.
  mutating func restore(_ settings: TilingLayoutSettings) {
    selection = settings.selection
    masterRatio = settings.masterRatio
    masterPlacement = settings.masterPlacement
    if splitRatio != settings.splitRatio {
      setSplitRatio(settings.splitRatio)
    }
    if preserveSplitDirections != settings.preserveSplitDirections {
      setPreserveSplitDirections(settings.preserveSplitDirections)
    }
  }
}

/// The configurable values of one layout.
struct TilingLayoutSettings: Equatable {
  let selection: LayoutSelection
  let masterRatio: CGFloat
  let masterPlacement: MasterPlacement
  let splitRatio: CGFloat
  let preserveSplitDirections: Bool
}

/// Animation and layout settings for the defaults and every layout, captured at one moment.
struct TilingSettingsSnapshot: Equatable {
  let animationDuration: Double
  let animationEasing: AnimationEasing
  let defaults: TilingLayoutSettings
  let byLayoutID: [TilingLayoutID: TilingLayoutSettings]
}
