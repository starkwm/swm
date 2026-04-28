enum ApplicationEvent {
  case launched(Process)
  case terminated(Process)
  case frontSwitched(Process)
}
