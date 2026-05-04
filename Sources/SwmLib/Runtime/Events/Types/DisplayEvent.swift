enum DisplayEvent: Sendable {
  case changed

  var type: EventType {
    switch self {
    case .changed:
      .displayChanged
    }
  }
}
