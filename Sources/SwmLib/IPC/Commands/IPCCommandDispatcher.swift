@MainActor
struct IPCCommandDispatcher {
  private let windows: Windows
  private let spaces: Spaces
  private let displays: Displays
  private let tiling: Tiling
  private let reload: ConfigReload
  private let activateSpace: (Int) async throws -> Void

  init(
    windows: Windows,
    spaces: Spaces,
    displays: Displays,
    tiling: Tiling,
    activateSpace: ((Int) async throws -> Void)? = nil
  ) {
    self.windows = windows
    self.spaces = spaces
    self.displays = displays
    self.tiling = tiling
    self.reload = ConfigReload(tiling: tiling, spaces: spaces, windows: windows)
    self.activateSpace =
      activateSpace ?? { index in
        try await Self.defaultActivateSpace(
          index: index,
          spaces: spaces,
          windows: windows,
          tiling: tiling
        )
      }
  }

  func dispatch(_ request: IPCRequest) async -> IPCResponse {
    switch request.command {
    case .query(let kind, let selection):
      return QueryCommandHandler(windows: windows, tiling: tiling).dispatch(
        id: request.id,
        kind: kind,
        selection: selection
      )

    case .spaceActivate(let index):
      return await IPCCommandError.catching(id: request.id) {
        guard index > 0 else {
          throw IPCCommandError.invalidRequest("invalid space index: \(index)")
        }
        try await activateSpace(index)
        return .acknowledged(id: request.id)
      }

    case .reload(let command):
      return IPCCommandError.catching(id: request.id) {
        switch command {
        case .begin(let processID):
          guard processID > 0 else {
            throw IPCCommandError.invalidRequest("invalid reload process ID: \(processID)")
          }
          return .success(id: request.id, message: try reload.begin(processID: processID))
        case .commit(let token):
          try reload.commit(token: token)
        case .rollback(let token):
          try reload.rollback(token: token)
        }
        return .acknowledged(id: request.id)
      }

    case .config(let command):
      return ConfigCommandHandler(
        windows: windows,
        spaces: spaces,
        tiling: tiling
      ).dispatch(id: request.id, command: command)

    case .displayFocus(let target):
      return DisplayCommandHandler(windows: windows, displays: displays).dispatch(
        id: request.id,
        target: target
      )

    case .window(let command):
      return await WindowCommandHandler(
        windows: windows,
        spaces: spaces,
        tiling: tiling
      ).dispatch(id: request.id, command: command)

    case .rule(let command):
      return RuleCommandHandler(tiling: tiling, reload: reload).dispatch(
        request,
        command: command
      )
    }
  }

  private static func defaultActivateSpace(
    index: Int,
    spaces: Spaces,
    windows: Windows,
    tiling: Tiling
  ) async throws {
    let snapshot = try await SpaceActivation.shared.activate(index: index)
    if let focusedID = snapshot.activeSpaceID,
      focusedID.rawValue != spaces.currentActiveSpaceID,
      let focusedSpace = snapshot.displays.flatMap(\.spaces).first(where: { $0.id == focusedID })
    {
      Events.shared.handle(
        .space(.changed(Space(id: focusedID.rawValue, type: SpaceType(focusedSpace.type))))
      )
    } else {
      SpaceLifecycleHandler(spaces: spaces, windows: windows, tiling: tiling)
        .refresh()
    }
  }
}
