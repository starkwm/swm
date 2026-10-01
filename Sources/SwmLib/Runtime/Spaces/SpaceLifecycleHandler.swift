/// Handles space lifecycle events.
@MainActor
struct SpaceLifecycleHandler {
  /// Space service updated by space events.
  let spaces: Spaces

  /// Window service refreshed after space changes.
  let windows: Windows

  /// Tiling coordinator refreshed after Space topology changes.
  let tiling: Tiling

  /// Handle one space lifecycle event.
  func handle(_ event: SpaceEvent) {
    switch event {
    case .changed(let space):
      spaceChanged(with: space)
    }
  }

  /// Refresh visible windows and layouts without changing the tracked focused Space.
  func refresh(spaceIDs: Set<UInt64>) {
    tiling.cancelAnimations()
    spaces.retainSettings(for: spaceIDs)
    windows.refreshWindows()
    replayLostFocusedEvent()
    tiling.reconcileAndReflowVisibleSpaces()
  }

  /// Update active-space tracking and refresh the runtime after a Space change.
  private func spaceChanged(with space: Space) {
    spaces.activeSpaceDidChange(to: space.id)
    refresh(spaceIDs: Set(Spaces.all().map(\.id)))

    log(
      "space changed \(space) current: \(spaces.currentActiveSpaceID.map(String.init) ?? "nil"), last: \(spaces.lastActiveSpaceID.map(String.init) ?? "nil")"
    )
  }

  /// Replay focused-window events that arrived before their windows were manageable.
  private func replayLostFocusedEvent() {
    for windowID in windows.lostFocusedWindowIDsSnapshot() {
      guard let window = windows.window(by: windowID) else { continue }
      guard !window.isMinimized else { continue }

      windows.removeLostFocusedEvent(for: windowID)
      Events.shared.post(.window(.focused(windowID)))
    }
  }
}
