struct RuntimeEventDispatcher {
  func emit(_ type: EventType, payload: Any, message: String, level: LogLevel = .info) {
    log(message, level: level)
  }
}
