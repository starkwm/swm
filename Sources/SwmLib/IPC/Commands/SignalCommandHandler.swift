import Foundation

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
    try SignalManager.shared.add(signal)

    return .success(id: request.id, message: "ok")
  }

  /// Remove an existing signal by one-based index or label.
  private func remove(_ request: IPCRequest) throws -> IPCResponse {
    guard request.args.count == 1 else {
      throw IPCCommandError.invalidRequest("invalid signal remove arguments")
    }

    try SignalManager.shared.remove(selector: request.args[0])

    return .success(id: request.id, message: "ok")
  }

  /// Return registered signals as sorted-key JSON.
  private func list(_ request: IPCRequest) throws -> IPCResponse {
    guard request.args.isEmpty else {
      throw IPCCommandError.invalidRequest("invalid signal list arguments")
    }

    let payload = SignalManager.shared.list().map(SignalSerializer.init)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]

    let data = try encoder.encode(payload)
    return .success(id: request.id, message: String(decoding: data, as: UTF8.self))
  }
}
