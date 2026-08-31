import CoreGraphics

/// Runtime events for display changes.
enum DisplayEvent: Sendable {
  /// The active display changed.
  case changed

  /// A display was added.
  case added(CGDirectDisplayID)

  /// A display was removed.
  case removed(CGDirectDisplayID)

  /// A display moved in the global desktop layout.
  case moved(CGDirectDisplayID)

  /// A display was resized.
  case resized(CGDirectDisplayID)
}
