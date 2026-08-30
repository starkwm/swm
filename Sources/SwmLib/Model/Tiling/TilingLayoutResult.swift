import CoreGraphics

/// Result of calculating one complete automatic-tiling layout.
enum TilingLayoutResult: Equatable {
  /// Target frames keyed by window ID.
  case frames([CGWindowID: CGRect])

  /// No frames were returned because a layout constraint could not be met.
  case insufficientSpace(TilingLayoutConstraint)
}

/// Explainable constraint that prevented automatic-tiling geometry.
enum TilingLayoutConstraint: Equatable {
  /// Padded visible bounds do not meet the minimum window size.
  case usableBounds

  /// A horizontal gap consumes the available width.
  case horizontalGap

  /// A vertical gap consumes the available height.
  case verticalGap

  /// The master pane is narrower than the minimum window width.
  case masterWidth

  /// The master pane is shorter than the minimum window height.
  case masterHeight

  /// The stack pane is narrower than the minimum window width.
  case stackWidth

  /// One or more stack rows are shorter than the minimum window height.
  case stackHeight

  /// A recursively split tile is narrower than the minimum window width.
  case tileWidth

  /// A recursively split tile is shorter than the minimum window height.
  case tileHeight
}
