struct DisplayCommandHandler {
  func dispatch(_ request: IPCRequest) -> IPCResponse {
    .failure(
      id: request.id,
      message: "unsupported display command: \(request.command)",
      errorCode: .unsupportedCommand
    )
  }
}
