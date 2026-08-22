/// Routes IPC requests to the command handler for their domain.
@MainActor
struct IPCCommandDispatcher {
  private let windowManager: WindowManager
  private let spaceManager: SpaceManager
  private let tilingManager: TilingManager

  /// Create a dispatcher backed by explicit window and space managers.
  init(
    windowManager: WindowManager,
    spaceManager: SpaceManager,
    tilingManager: TilingManager
  ) {
    self.windowManager = windowManager
    self.spaceManager = spaceManager
    self.tilingManager = tilingManager
  }

  /// Dispatch a request to its domain-specific command handler.
  func dispatch(_ request: IPCRequest) -> IPCResponse {
    switch request.domain {
    case .query:
      return QueryCommandHandler(windowManager: windowManager).dispatch(request)

    case .space:
      return SpaceCommandHandler(
        spaceManager: spaceManager,
        tilingManager: tilingManager
      ).dispatch(request)

    case .config:
      return ConfigCommandHandler(
        spaceManager: spaceManager,
        tilingManager: tilingManager
      ).dispatch(request)

    case .display:
      return DisplayCommandHandler().dispatch(request)

    case .window:
      return WindowCommandHandler(
        windowManager: windowManager,
        spaceManager: spaceManager
      ).dispatch(request)

    case .signal:
      return SignalCommandHandler().dispatch(request)
    }
  }
}
