struct SpaceLifecycleHandler {
  let windowManager: WindowManager

  func handle(_ event: SpaceEvent) {
    switch event {
    case .changed(let space):
      spaceChanged(with: space)
    }
  }

  private func spaceChanged(with space: Space) {
    windowManager.refreshWindows()
    log("space changed \(space)")
  }
}
