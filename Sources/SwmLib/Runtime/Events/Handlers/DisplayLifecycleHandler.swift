/// Handles display lifecycle events.
struct DisplayLifecycleHandler {
  /// Display manager updated by display events.
  let displayManager: DisplayManager

  /// Handle one display lifecycle event.
  func handle(_ event: DisplayEvent) {
    switch event {
    case .changed:
      displayChanged()
    }
  }

  /// Update active-display tracking.
  private func displayChanged() {
    displayManager.activeDisplayDidChange()

    log(
      "display changed current: \(displayManager.currentActiveDisplayID ?? "nil"), last: \(displayManager.lastActiveDisplayID ?? "nil")"
    )
  }
}
