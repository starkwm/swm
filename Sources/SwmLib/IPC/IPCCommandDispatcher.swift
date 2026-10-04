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
  func dispatch(_ request: IPCRequest) async -> IPCResponse {
    switch request.domain {
    case .query:
      return QueryCommandHandler(windows: windows, tiling: tiling).dispatch(request)

    case .space:
      return await SpaceCommandHandler(
        spaces: spaces,
        tiling: tiling,
        activateSpace: activateSpace
      ).dispatch(request)

    case .config:
      return ConfigCommandHandler(
        windows: windows,
        spaces: spaces,
        tiling: tiling
      ).dispatch(request)

    case .display:
      return DisplayCommandHandler().dispatch(request)

    case .window:
      return await WindowCommandHandler(
        windows: windows,
        spaces: spaces,
        tiling: tiling
      ).dispatch(request)

    case .rule:
      return RuleCommandHandler(tiling: tiling).dispatch(request)

    case .signal:
      return SignalCommandHandler().dispatch(request)
    }
  }

  /// Refresh runtime state even when a bridge activation produces no workspace notification.
  private func activateSpace(index: Int) async throws {
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
        .refresh(spaceIDs: Set(snapshot.allSpaceIDs.map(\.rawValue)))
    }
  }
}
