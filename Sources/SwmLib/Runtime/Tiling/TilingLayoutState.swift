import CoreGraphics

struct TilingLayoutState {
  var selection: LayoutSelection

  var masterRatio: CGFloat

  var masterPlacement: MasterPlacement

  var splitRatio: CGFloat

  var preserveSplitDirections: Bool

  var tree: TilingTree?

  var omittedWindowIDs: Set<CGWindowID>

  var focusedWindowID: CGWindowID?

  var settings: TilingLayoutSettings {
    TilingLayoutSettings(
      selection: selection,
      masterRatio: masterRatio,
      masterPlacement: masterPlacement,
      splitRatio: splitRatio,
      preserveSplitDirections: preserveSplitDirections
    )
  }

  mutating func setSplitRatio(_ ratio: CGFloat) {
    splitRatio = ratio
    tree = tree?.settingSplitRatios(ratio)
  }

  mutating func setPreserveSplitDirections(_ enabled: Bool) {
    preserveSplitDirections = enabled
    if !enabled {
      tree = tree?.clearingSplitDirections()
    }
  }

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

struct TilingLayoutSettings: Equatable {
  let selection: LayoutSelection
  let masterRatio: CGFloat
  let masterPlacement: MasterPlacement
  let splitRatio: CGFloat
  let preserveSplitDirections: Bool
}

struct TilingSettingsSnapshot: Equatable {
  let animationDuration: Double
  let animationEasing: AnimationEasing
  let defaults: TilingLayoutSettings
  let byLayoutID: [TilingLayoutID: TilingLayoutSettings]
}
