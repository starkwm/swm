/// User-visible signal event names supported by swm.
enum SignalEvent: String, Codable, CaseIterable, Sendable {
  case applicationLaunched = "application-launched"
  case applicationTerminated = "application-terminated"
  case applicationFrontSwitched = "application-front-switched"
  case windowCreated = "window-created"
  case windowDestroyed = "window-destroyed"
  case windowFocused = "window-focused"
  case windowMoved = "window-moved"
  case windowResized = "window-resized"
  case windowMinimized = "window-minimized"
  case windowDeminimized = "window-deminimized"
  case spaceChanged = "space-changed"
  case displayChanged = "display-changed"
  case displayAdded = "display-added"
  case displayRemoved = "display-removed"
  case displayMoved = "display-moved"
  case displayResized = "display-resized"

  /// Whether this event can be filtered by focused/current active state.
  var supportsActiveFilter: Bool {
    switch self {
    case .applicationLaunched, .applicationTerminated, .applicationFrontSwitched,
      .windowCreated, .windowDestroyed, .windowFocused, .windowMoved, .windowResized,
      .windowMinimized, .windowDeminimized:
      true
    case .spaceChanged, .displayChanged, .displayAdded, .displayRemoved, .displayMoved,
      .displayResized:
      false
    }
  }
}
