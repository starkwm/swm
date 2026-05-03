struct IPCCommandDispatcher {
  private let windowManager: WindowManager

  init(windowManager: WindowManager = WindowManager(workspace: Workspace())) {
    self.windowManager = windowManager
  }

  func dispatch(_ request: IPCRequest) -> IPCResponse {
    switch request.domain {
    case .query:
      return QueryCommandHandler(windowManager: windowManager).dispatch(request)

    case .config, .display, .space, .window:
      return .failure(
        id: request.id,
        message: "unsupported \(request.domain.rawValue) command: \(request.command)",
        errorCode: .unsupportedCommand
      )
    }
  }
}
