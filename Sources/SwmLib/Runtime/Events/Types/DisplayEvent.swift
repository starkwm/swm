/// Runtime events for display changes.
enum DisplayEvent: Sendable {
  /// The active display changed.
  case changed

  /// Generic event type for logging and routing.
  var type: EventType {
    switch self {
    case .changed:
      .displayChanged
    }
  }
}
