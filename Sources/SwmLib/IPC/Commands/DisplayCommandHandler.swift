struct DisplayCommandHandler {
  func dispatch(_ request: IPCRequest) -> IPCResponse {
    IPCCommandError.catching(id: request.id) {
      throw IPCCommandError.unsupportedCommand("unsupported display command: \(request.command)")
    }
  }
}
