/// Flat runtime event identifiers.
enum EventType: String {
  /// Application launched or became observable.
  case applicationLaunched

  /// Application terminated.
  case applicationTerminated

  /// Frontmost application changed.
  case applicationFrontSwitched

  /// Window was created.
  case windowCreated

  /// Window was destroyed.
  case windowDestroyed

  /// Focused window changed.
  case windowFocused

  /// Window moved.
  case windowMoved

  /// Window resized.
  case windowResized

  /// Window was minimized.
  case windowMinimized

  /// Window was restored from minimized state.
  case windowDeminimized

  /// Active space changed.
  case spaceChanged

  /// Active display changed.
  case displayChanged
}
