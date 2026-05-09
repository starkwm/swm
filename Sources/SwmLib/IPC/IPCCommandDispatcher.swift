/// Routes IPC requests to the command handler for their domain.
struct IPCCommandDispatcher {
  private let windowManager: WindowManager
  private let spaceManager: SpaceManager

  /// Create a dispatcher backed by shared window and space managers.
  init(
    windowManager: WindowManager = WindowManager(workspace: Workspace()),
    spaceManager: SpaceManager = SpaceManager()
  ) {
    self.windowManager = windowManager
    self.spaceManager = spaceManager
  }

  /// Dispatch a request to its domain-specific command handler.
  func dispatch(_ request: IPCRequest) -> IPCResponse {
    switch request.domain {
    case .query:
      return QueryCommandHandler(windowManager: windowManager).dispatch(request)

    case .space:
      return SpaceCommandHandler(spaceManager: spaceManager).dispatch(request)

    case .config:
      return ConfigCommandHandler(spaceManager: spaceManager).dispatch(request)

    case .display:
      return DisplayCommandHandler().dispatch(request)

    case .window:
      return WindowCommandHandler(
        windowManager: windowManager,
        spaceManager: spaceManager
      ).dispatch(request)
    }
  }
}
