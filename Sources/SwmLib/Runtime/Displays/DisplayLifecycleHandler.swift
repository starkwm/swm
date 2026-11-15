@MainActor
struct DisplayLifecycleHandler {
  let displays: Displays

  let tiling: Tiling

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

  private func displayChanged() {
    displays.activeDisplayDidChange()
    tiling.reconcileAndReflowVisibleSpaces()

    log("display changed \(displays.activeDisplay)")
  }

  private func displayReconfigured(displayID: UInt32, message: String) {
    tiling.cancelAnimations()
    tiling.reconcileAndReflowVisibleSpaces()
    log("\(message) id: \(displayID), \(displays.activeDisplay)")
  }
}
