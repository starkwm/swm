import CoreGraphics

/// Runtime events for window lifecycle and state changes.
enum WindowEvent: Sendable {
  /// Window was created for a process.
  case created(pid_t, CGWindowID)

  /// Managed window was destroyed.
  case destroyed(Window)

  /// Window became focused.
  case focused(CGWindowID)

  /// Window moved.
  case moved(CGWindowID)

  /// Window resized.
  case resized(CGWindowID)

  /// Managed window was minimized.
  case minimized(Window)

  /// Managed window was restored from minimized state.
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
