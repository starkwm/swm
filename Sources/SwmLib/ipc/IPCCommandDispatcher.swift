protocol IPCCommandDispatcher {
  func dispatch(_ request: IPCRequest) -> IPCResponse
}

struct DefaultIPCCommandDispatcher: IPCCommandDispatcher {
  func dispatch(_ request: IPCRequest) -> IPCResponse {
    switch request.domain {
    case .config, .display, .query, .space, .window:
      return .failure(
        id: request.id,
        message: "unsupported \(request.domain.rawValue) command: \(request.command)",
        errorCode: .unsupportedCommand
      )
    }
  }
}
