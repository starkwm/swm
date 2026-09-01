/// Routes IPC requests to the command handler for their domain.
@MainActor
struct IPCCommandDispatcher {
  private let windowManager: Windows
  private let spaceManager: Spaces
  private let tilingManager: Tiling

  /// Create a dispatcher backed by explicit window and space managers.
  init(
    windowManager: Windows,
    spaceManager: Spaces,
    tilingManager: Tiling
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
        spaceManager: spaceManager,
        tilingManager: tilingManager
      ).dispatch(request)

    case .signal:
      return SignalCommandHandler().dispatch(request)
    }
  }
}
