/// Handles display IPC commands.
struct DisplayCommandHandler {
  /// Dispatch a display IPC request.
  func dispatch(_ request: IPCRequest) -> IPCResponse {
    IPCCommandError.catching(id: request.id) {
      throw IPCCommandError.unsupportedCommand("unsupported display command: \(request.command)")
    }
  }
}
