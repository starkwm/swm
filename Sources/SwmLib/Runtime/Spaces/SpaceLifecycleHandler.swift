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

  /// Update active-space tracking, refresh windows, and replay deferred focus.
  private func spaceChanged(with space: Space) {
    spaces.activeSpaceDidChange(to: space.id)
    spaces.retainSettings(for: Set(Spaces.all().map(\.id)))
    windows.refreshWindows()
    replayLostFocusedEvent()
    tiling.reconcileAndReflowVisibleSpaces()

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
