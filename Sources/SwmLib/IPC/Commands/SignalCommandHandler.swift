/// Handles IPC commands that register, remove, and list runtime signals.
struct SignalCommandHandler {
  /// Dispatch a signal IPC request.
  func dispatch(_ request: IPCRequest) -> IPCResponse {
    IPCCommandError.catching(id: request.id) {
      switch request.command {
      case "--add":
        return try add(request)
      case "--remove":
        return try remove(request)
      case "--list":
        return try list(request)
      default:
        throw IPCCommandError.unsupportedCommand("unsupported signal command: \(request.command)")
      }
    }
  }

  /// Add a new signal registration.
  private func add(_ request: IPCRequest) throws -> IPCResponse {
    let signal = try Signal.parseAdd(arguments: request.args)
    try Signals.shared.add(signal)

    return .success(id: request.id, message: "ok")
  }

  /// Remove an existing signal by one-based index or label.
  private func remove(_ request: IPCRequest) throws -> IPCResponse {
    let selector = try IPCArguments(request.args, context: "signal remove").requiredValue()
    try Signals.shared.remove(selector: selector)

    return .success(id: request.id, message: "ok")
  }

  /// Return registered signals as sorted-key JSON.
  private func list(_ request: IPCRequest) throws -> IPCResponse {
    try IPCArguments(request.args, context: "signal list").requireEmpty()

    let payload = Signals.shared.list().map(SignalSerializer.init)
    return try .json(id: request.id, payload: payload)
  }
}
