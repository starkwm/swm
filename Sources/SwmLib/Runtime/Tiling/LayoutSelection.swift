/// User-facing automatic layout selection, including unmanaged floating windows.
enum LayoutSelection: String, Equatable {
  /// Leave windows unmanaged by automatic tiling.
  case float

  /// Arrange windows as one master pane and a stack.
  case master

  /// Recursively bisect the longest edge of the remaining region.
  case dwindle
}
