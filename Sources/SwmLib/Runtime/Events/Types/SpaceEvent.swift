/// Runtime events for space changes.
enum SpaceEvent: Sendable {
  /// The active space changed.
  case changed(Space)

  /// Generic event type for logging and routing.
  var type: EventType {
    switch self {
    case .changed:
      .spaceChanged
    }
  }
}
