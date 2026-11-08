/// Runtime events for space changes.
enum SpaceEvent: Sendable {
  /// The active space changed.
  case changed(Space)

  /// The active space changed, but the new active space could not be read.
  case unavailable
}
