import CoreGraphics

enum WindowEvent {
  case created(pid_t, CGWindowID)
  case destroyed(Window)
  case focused(CGWindowID)
  case moved(CGWindowID)
  case resized(CGWindowID)
  case minimized(Window)
  case deminimized(Window)
}
