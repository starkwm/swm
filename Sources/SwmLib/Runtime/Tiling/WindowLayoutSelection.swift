/// Per-window participation in an automatic Space layout.
enum WindowLayoutSelection: String, Equatable {
  /// Remove the window from automatic layout geometry.
  case float

  /// Return the window to automatic layout geometry.
  case tile

  /// Toggle the window between floating and tiled geometry.
  case toggle
}
