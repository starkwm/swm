struct SpaceLifecycleHandler {
  let spaceManager: SpaceManager

  func handle(_ event: SpaceEvent) {
    switch event {
    case .changed(let space):
      spaceChanged(with: space)
    }
  }

  private func spaceChanged(with space: Space) {
    spaceManager.activeSpaceDidChange()

    log(
      "space changed \(space) current: \(spaceManager.currentActiveSpaceID.map(String.init) ?? "nil"), last: \(spaceManager.lastActiveSpaceID.map(String.init) ?? "nil")"
    )
  }
}
