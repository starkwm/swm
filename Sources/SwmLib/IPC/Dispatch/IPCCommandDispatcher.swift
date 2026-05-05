struct IPCCommandDispatcher {
  private let windowManager: WindowManager
  private let spaceManager: SpaceManager
  private let displayManager: DisplayManager
  private let activeSpaceID: () -> UInt64

  init(
    windowManager: WindowManager = WindowManager(workspace: Workspace()),
    spaceManager: SpaceManager = SpaceManager(),
    displayManager: DisplayManager = DisplayManager(),
    activeSpaceID: @escaping () -> UInt64 = { Space.active().id }
  ) {
    self.windowManager = windowManager
    self.spaceManager = spaceManager
    self.displayManager = displayManager
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

    case .config:
      return ConfigCommandHandler().dispatch(request)

    case .display:
      return DisplayCommandHandler(displayManager: displayManager).dispatch(request)

    case .window:
      return WindowCommandHandler().dispatch(request)
    }
  }
}
