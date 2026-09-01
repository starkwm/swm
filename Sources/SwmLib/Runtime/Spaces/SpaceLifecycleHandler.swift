/// Handles space lifecycle events.
@MainActor
struct SpaceLifecycleHandler {
  /// Space manager updated by space events.
  let spaceManager: Spaces

  /// Window manager refreshed after space changes.
  let windowManager: Windows

  /// Tiling coordinator refreshed after Space topology changes.
  let tilingManager: Tiling

  /// Handle one space lifecycle event.
  func handle(_ event: SpaceEvent) {
    switch event {
    case .changed(let space):
      spaceChanged(with: space)
    }
  }

  /// Update active-space tracking, refresh windows, and replay deferred focus.
  private func spaceChanged(with space: Space) {
    spaceManager.activeSpaceDidChange(to: space.id)
    spaceManager.retainSettings(for: Set(Spaces.all().map(\.id)))
    windowManager.refreshWindows()
    replayLostFocusedEvent()
    tilingManager.reconcileAndReflowVisibleSpaces()

    log(
      "space changed \(space) current: \(spaceManager.currentActiveSpaceID.map(String.init) ?? "nil"), last: \(spaceManager.lastActiveSpaceID.map(String.init) ?? "nil")"
    )
  }

  /// Replay focused-window events that arrived before their windows were manageable.
  private func replayLostFocusedEvent() {
    for windowID in windowManager.lostFocusedWindowIDsSnapshot() {
      guard let window = windowManager.window(by: windowID) else { continue }
      guard !window.isMinimized else { continue }

      windowManager.removeLostFocusedEvent(for: windowID)
      Events.shared.post(.window(.focused(windowID)))
    }
  }
}
