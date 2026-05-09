/// Runtime events for application process lifecycle changes.
enum ApplicationEvent: Sendable {
  /// A process launched or became observable.
  case launched(Process)

  /// A tracked process terminated.
  case terminated(Process)

  /// The frontmost process changed.
  case frontSwitched(Process)

  /// Generic event type for logging and routing.
  var type: EventType {
    switch self {
    case .launched:
      .applicationLaunched
    case .terminated:
      .applicationTerminated
    case .frontSwitched:
      .applicationFrontSwitched
    }
  }
}
