/// Handles display lifecycle events.
@MainActor
struct DisplayLifecycleHandler {
  /// Display manager updated by display events.
  let displayManager: Displays

  /// Tiling coordinator refreshed after display topology changes.
  let tilingManager: Tiling

  /// Handle one display lifecycle event.
  func handle(_ event: DisplayEvent) {
    switch event {
    case .changed:
      displayChanged()
    case .added(let displayID):
      displayReconfigured(displayID: displayID, message: "display added")
    case .removed(let displayID):
      displayReconfigured(displayID: displayID, message: "display removed")
    case .moved(let displayID):
      displayReconfigured(displayID: displayID, message: "display moved")
    case .resized(let displayID):
      displayReconfigured(displayID: displayID, message: "display resized")
    }
  }

  /// Update active-display tracking.
  private func displayChanged() {
    displayManager.activeDisplayDidChange()
    tilingManager.reconcileAndReflowVisibleSpaces()

    log(
      "display changed current: \(displayManager.currentActiveDisplayID ?? "nil"), last: \(displayManager.lastActiveDisplayID ?? "nil")"
    )
  }

  /// Log display reconfiguration without mutating active-display tracking.
  private func displayReconfigured(displayID: UInt32, message: String) {
    tilingManager.reconcileAndReflowVisibleSpaces()
    log(
      "\(message) id: \(displayID), current: \(displayManager.currentActiveDisplayID ?? "nil"), last: \(displayManager.lastActiveDisplayID ?? "nil")"
    )
  }
}
