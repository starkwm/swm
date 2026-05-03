enum ApplicationEvent: Sendable {
  case launched(Process)
  case terminated(Process)
  case frontSwitched(Process)

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
