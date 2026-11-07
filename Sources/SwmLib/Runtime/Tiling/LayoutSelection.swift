/// User-facing automatic layout selection, including unmanaged floating windows.
public enum LayoutSelection: String, Equatable, CaseIterable, Sendable {
  /// Leave windows unmanaged by automatic tiling.
  case float

  /// Arrange windows as one master pane and a stack.
  case master

  /// Stack every window across the complete available bounds.
  case monocle

  /// Recursively bisect the longest edge of the remaining region.
  case dwindle
}
