struct SpaceLifecycleHandler {
  let spaceManager: SpaceManager
  let windowManager: WindowManager

  func handle(_ event: SpaceEvent) {
    switch event {
    case .changed(let space):
      spaceChanged(with: space)
    }
  }

  private func spaceChanged(with space: Space) {
    spaceManager.activeSpaceDidChange()
    windowManager.refreshWindows()
    replayLostFocusedEvent()

    log(
      "space changed \(space) current: \(spaceManager.currentActiveSpaceID.map(String.init) ?? "nil"), last: \(spaceManager.lastActiveSpaceID.map(String.init) ?? "nil")"
    )
  }

  private func replayLostFocusedEvent() {
    for windowID in windowManager.lostFocusedWindowIDsSnapshot() {
      guard let window = windowManager.window(by: windowID) else { continue }
      guard !window.isMinimized else { continue }

      windowManager.removeLostFocusedEvent(for: windowID)
      EventManager.shared.post(.window(.focused(windowID)))
    }
  }
}
