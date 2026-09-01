/// Routes IPC requests to the command handler for their domain.
@MainActor
struct IPCCommandDispatcher {
  private let windows: Windows
  private let spaces: Spaces
  private let tiling: Tiling

  /// Create a dispatcher backed by explicit window and Space services.
  init(
    windows: Windows,
    spaces: Spaces,
    tiling: Tiling
  ) {
    self.windows = windows
    self.spaces = spaces
    self.tiling = tiling
  }

  /// Dispatch a request to its domain-specific command handler.
  func dispatch(_ request: IPCRequest) -> IPCResponse {
    switch request.domain {
    case .query:
      return QueryCommandHandler(windows: windows).dispatch(request)

    case .space:
      return SpaceCommandHandler(
        spaces: spaces,
        tiling: tiling
      ).dispatch(request)

    case .config:
      return ConfigCommandHandler(
        spaces: spaces,
        tiling: tiling
      ).dispatch(request)

    case .display:
      return DisplayCommandHandler().dispatch(request)

    case .window:
      return WindowCommandHandler(
        windows: windows,
        spaces: spaces,
        tiling: tiling
      ).dispatch(request)

    case .signal:
      return SignalCommandHandler().dispatch(request)
    }
  }
}
