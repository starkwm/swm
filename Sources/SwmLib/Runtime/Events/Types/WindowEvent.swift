import CoreGraphics

/// Runtime events for window lifecycle and state changes.
enum WindowEvent: Sendable {
  /// A window was created for a process.
  case created(pid_t, CGWindowID)

  /// A managed window was destroyed.
  case destroyed(Window)

  /// A window became focused.
  case focused(CGWindowID)

  /// A window moved.
  case moved(CGWindowID)

  /// A window resized.
  case resized(CGWindowID)

  /// A managed window was minimized.
  case minimized(Window)

  /// A managed window was restored from minimized state.
  case deminimized(Window)

  /// Generic event type for logging and routing.
  var type: EventType {
    switch self {
    case .created:
      .windowCreated
    case .destroyed:
      .windowDestroyed
    case .focused:
      .windowFocused
    case .moved:
      .windowMoved
    case .resized:
      .windowResized
    case .minimized:
      .windowMinimized
    case .deminimized:
      .windowDeminimized
    }
  }
}
