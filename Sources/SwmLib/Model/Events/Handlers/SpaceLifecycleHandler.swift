/// Handles space lifecycle events.
struct SpaceLifecycleHandler {
  /// Space manager updated by space events.
  let spaceManager: SpaceManager

  /// Window manager refreshed after space changes.
  let windowManager: WindowManager

  /// Handle one space lifecycle event.
  func handle(_ event: SpaceEvent) {
    switch event {
    case .changed(let space):
      spaceChanged(with: space)
    }
  }

  /// Update active-space tracking, refresh windows, and replay deferred focus.
  private func spaceChanged(with space: Space) {
    spaceManager.activeSpaceDidChange()
    windowManager.refreshWindows()
    replayLostFocusedEvent()

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
      EventManager.shared.post(.window(.focused(windowID)))
    }
  }
}
