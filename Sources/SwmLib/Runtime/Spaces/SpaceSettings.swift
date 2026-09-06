/// Layout settings applied when placing windows on a space.
struct SpaceSettings: Equatable {
  /// Default settings used for spaces without explicit overrides.
  static let defaults = SpaceSettings(
    paddingEnabled: true,
    gapEnabled: true,
    padding: .zero,
    gap: 0
  )

  /// Whether padding should affect layout calculations.
  var paddingEnabled: Bool

  /// Whether gaps should affect layout calculations.
  var gapEnabled: Bool

  /// Padding around the usable area.
  var padding: SpacePadding

  /// Gap between grid cells in points.
  var gap: Int
}

/// Per-side padding applied inside a space's visible frame.
struct SpacePadding: Equatable {
  /// Padding with every side set to zero.
  static let zero = SpacePadding(top: 0, bottom: 0, left: 0, right: 0)

  /// Top padding in points.
  var top: Int

  /// Bottom padding in points.
  var bottom: Int

  /// Left padding in points.
  var left: Int

  /// Right padding in points.
  var right: Int

  /// Return padding with every side clamped to zero or greater.
  func clamped() -> SpacePadding {
    SpacePadding(
      top: max(0, top),
      bottom: max(0, bottom),
      left: max(0, left),
      right: max(0, right)
    )
  }
}
