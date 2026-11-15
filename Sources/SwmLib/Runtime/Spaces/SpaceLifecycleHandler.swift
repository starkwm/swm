@MainActor
struct SpaceLifecycleHandler {
  let spaces: Spaces

  let windows: Windows

  let tiling: Tiling

  func handle(_ event: SpaceEvent) {
    switch event {
    case .changed(let space):
      spaceChanged(with: space)
    case .unavailable:
      spaces.activeSpaceBecameUnavailable()
      refresh()
      log("space changed to an unavailable space \(spaces.activeSpace)", level: .warn)
    }
  }

  func refresh() {
    tiling.cancelAnimations()
    windows.refreshWindows()
    replayLostFocusedEvent()
    tiling.reconcileAndReflowVisibleSpaces()
  }

  private func spaceChanged(with space: Space) {
    spaces.activeSpaceDidChange(to: space.id)
    refresh()

    log("space changed \(space) \(spaces.activeSpace)")
  }

  private func replayLostFocusedEvent() {
    for windowID in windows.lostFocusedWindowIDsSnapshot() {
      guard let window = windows.window(by: windowID) else { continue }
      guard !window.isMinimized else { continue }

      windows.replayLostFocusedEvent(for: windowID)
    }
  }
}
