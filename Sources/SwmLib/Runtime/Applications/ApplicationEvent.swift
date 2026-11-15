enum ApplicationEvent: Sendable {
  case launched(Process)

  case terminated(Process)

  case frontSwitched(Process)
}
