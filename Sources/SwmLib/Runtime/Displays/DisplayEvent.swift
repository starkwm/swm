import CoreGraphics

enum DisplayEvent: Sendable {
  case changed

  case added(CGDirectDisplayID)

  case removed(CGDirectDisplayID)

  case moved(CGDirectDisplayID)

  case resized(CGDirectDisplayID)
}
