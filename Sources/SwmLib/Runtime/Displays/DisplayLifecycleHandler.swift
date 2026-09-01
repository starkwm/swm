/// Handles display lifecycle events.
@MainActor
struct DisplayLifecycleHandler {
  /// Display service updated by display events.
  let displays: Displays

  /// Tiling coordinator refreshed after display topology changes.
  let tiling: Tiling

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
    displays.activeDisplayDidChange()
    tiling.reconcileAndReflowVisibleSpaces()

    log(
      "display changed current: \(displays.currentActiveDisplayID ?? "nil"), last: \(displays.lastActiveDisplayID ?? "nil")"
    )
  }

  /// Log display reconfiguration without mutating active-display tracking.
  private func displayReconfigured(displayID: UInt32, message: String) {
    tiling.reconcileAndReflowVisibleSpaces()
    log(
      "\(message) id: \(displayID), current: \(displays.currentActiveDisplayID ?? "nil"), last: \(displays.lastActiveDisplayID ?? "nil")"
    )
  }
}
