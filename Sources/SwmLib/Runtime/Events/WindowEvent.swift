import CoreGraphics

enum WindowEvent {
  case created(pid_t, CGWindowID)
  case destroyed(Window)
  case focused(CGWindowID)
  case moved(CGWindowID)
  case resized(CGWindowID)
  case minimized(Window)
  case deminimized(Window)

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
