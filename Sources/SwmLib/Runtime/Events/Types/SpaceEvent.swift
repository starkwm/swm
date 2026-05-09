/// Runtime events for space changes.
enum SpaceEvent: Sendable {
  /// The active space changed.
  case changed(Space)
}
