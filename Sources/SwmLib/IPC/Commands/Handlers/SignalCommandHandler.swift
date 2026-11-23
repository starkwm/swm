@MainActor
struct SignalCommandHandler {
  var signals = Signals.shared

  var reload: ConfigReload?

  func dispatch(_ request: IPCRequest, command: IPCCommand.Signal) -> IPCResponse {
    IPCCommandError.catching(id: request.id) {
      let staging = reload?.staging(for: request)
      switch command {
      case .add(let arguments):
        let signal = try Signal.parseAdd(arguments: arguments)
        if let staging { try staging.addSignal(signal) } else { try signals.add(signal) }
      case .remove(let selector):
        if let staging {
          try staging.removeSignal(selector: selector)
        } else {
          try signals.remove(selector: selector)
        }
      case .clear:
        if let staging { staging.removeAllSignals() } else { signals.removeAll() }
      case .list:
        let registered =
          staging.map {
            $0.signals.enumerated().map { IndexedSignal(index: $0.offset + 1, signal: $0.element) }
          } ?? signals.list()
        return try .json(id: request.id, payload: registered.map(SignalSerializer.init))
      }
      return .acknowledged(id: request.id)
    }
  }
}
