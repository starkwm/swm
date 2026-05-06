struct ConfigCommandHandler {
  func dispatch(_ request: IPCRequest) -> IPCResponse {
    IPCCommandError
      .unsupportedCommand("unsupported config command: \(request.command)")
      .response(id: request.id)
  }
}
