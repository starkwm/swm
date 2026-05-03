struct IPCCommandDispatcher {
  private let windowManager: WindowManager
  private let spaceManager: SpaceManager
  private let activeSpaceID: () -> UInt64

  init(
    windowManager: WindowManager = WindowManager(workspace: Workspace()),
    spaceManager: SpaceManager = SpaceManager(),
    activeSpaceID: @escaping () -> UInt64 = { Space.active().id }
  ) {
    self.windowManager = windowManager
    self.spaceManager = spaceManager
    self.activeSpaceID = activeSpaceID
  }

  func dispatch(_ request: IPCRequest) -> IPCResponse {
    switch request.domain {
    case .query:
      return QueryCommandHandler(windowManager: windowManager).dispatch(request)

    case .space:
      return SpaceCommandHandler(
        spaceManager: spaceManager,
        activeSpaceID: activeSpaceID
      ).dispatch(request)

    case .config, .display, .window:
      return .failure(
        id: request.id,
        message: "unsupported \(request.domain.rawValue) command: \(request.command)",
        errorCode: .unsupportedCommand
      )
    }
  }
}
