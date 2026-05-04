struct WindowCommandHandler {
  func dispatch(_ request: IPCRequest) -> IPCResponse {
    .failure(
      id: request.id,
      message: "unsupported window command: \(request.command)",
      errorCode: .unsupportedCommand
    )
  }
}
