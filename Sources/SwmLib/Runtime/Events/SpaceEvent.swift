enum SpaceEvent: Sendable {
  case changed(Space)

  var type: EventType {
    switch self {
    case .changed:
      .spaceChanged
    }
  }
}
