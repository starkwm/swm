/// Runtime events for application process lifecycle changes.
enum ApplicationEvent: Sendable {
  /// Process launched or became observable.
  case launched(Process)

  /// Tracked process terminated.
  case terminated(Process)

  /// The frontmost process changed.
  case frontSwitched(Process)
}
