/// Handles IPC commands that register, remove, clear, and list runtime signals.
@MainActor
struct SignalCommandHandler {
  /// Live signal registry.
  var signals = Signals.shared

  /// Open configuration reload whose tagged requests change staged signals.
  var reload: ConfigReload?

  /// Dispatch a signal IPC request.
  func dispatch(_ request: IPCRequest) -> IPCResponse {
    IPCCommandError.catching(id: request.id) {
      let staging = reload?.staging(for: request)
      switch request.command {
      case "--add":
        let signal = try Signal.parseAdd(arguments: request.args)
        if let staging { try staging.addSignal(signal) } else { try signals.add(signal) }
      case "--remove":
        let selector = try IPCArguments(request.args, context: "signal remove").requiredValue()
        if let staging {
          try staging.removeSignal(selector: selector)
        } else {
          try signals.remove(selector: selector)
        }
      case "--clear":
        try IPCArguments(request.args, context: "signal clear").requireEmpty()
        if let staging { staging.removeAllSignals() } else { signals.removeAll() }
      case "--list":
        try IPCArguments(request.args, context: "signal list").requireEmpty()
        let registered =
          staging.map {
            $0.signals.enumerated().map { IndexedSignal(index: $0.offset + 1, signal: $0.element) }
          } ?? signals.list()
        return try .json(id: request.id, payload: registered.map(SignalSerializer.init))
      default:
        throw IPCCommandError.unsupportedCommand("unsupported signal command: \(request.command)")
      }
      return .acknowledged(id: request.id)
    }
  }
}
