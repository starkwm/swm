struct DisplayLifecycleHandler {
  let displayManager: DisplayManager

  func handle(_ event: DisplayEvent) {
    switch event {
    case .changed:
      displayChanged()
    }
  }

  private func displayChanged() {
    displayManager.activeDisplayDidChange()

    log(
      "display changed current: \(displayManager.currentActiveDisplayID ?? "nil"), last: \(displayManager.lastActiveDisplayID ?? "nil")"
    )
  }
}
