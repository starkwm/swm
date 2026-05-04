struct ConfigCommandHandler {
  func dispatch(_ request: IPCRequest) -> IPCResponse {
    .failure(
      id: request.id,
      message: "unsupported config command: \(request.command)",
      errorCode: .unsupportedCommand
    )
  }
}
