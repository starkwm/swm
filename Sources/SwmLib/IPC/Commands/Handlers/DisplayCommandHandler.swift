import AppKit

@MainActor
struct DisplayCommandHandler {
  private let windows: Windows
  private let displays: Displays

  init(windows: Windows, displays: Displays) {
    self.windows = windows
    self.displays = displays
  }

  func dispatch(id: String, target: DisplayTarget) -> IPCResponse {
    IPCCommandError.catching(id: id) {
      let screens = NSScreen.arrangedScreens
      let sourceID = currentDisplayID()
      guard
        let targetID = target.displayID(
          from: sourceID,
          displays: screens.map { DisplayCandidate(id: $0.uuid, frame: $0.axFrame) },
          recentID: displays.lastActiveDisplayID,
          mouseLocation: CGEvent(source: nil)?.location
        ),
        let screen = screens.first(where: { $0.uuid == targetID })
      else {
        throw IPCCommandError.invalidRequest("could not locate display")
      }

      guard targetID != sourceID else { return .acknowledged(id: id) }

      if let window = frontmostWindow(on: screen) {
        try window.focusOrThrow()
        return .acknowledged(id: id)
      }

      let center = CGPoint(x: screen.axFrame.midX, y: screen.axFrame.midY)
      CGWarpMouseCursorPosition(center)
      guard WindowServerClient.shared.focusFrontmostWindow(at: center) else {
        throw IPCCommandError.internalError("could not focus display")
      }

      return .acknowledged(id: id)
    }
  }

  private func currentDisplayID() -> String? {
    if let window = windows.currentFocusedWindowID.flatMap(windows.window(by:)),
      let frame = window.frame(),
      let screen = NSScreen.screen(containingLargestIntersectionWith: frame)
    {
      return screen.uuid
    }

    return Spaces.active().flatMap(Spaces.display(for:))
  }

  private func frontmostWindow(on screen: NSScreen) -> Window? {
    WindowServerClient.shared.onScreenWindowIDs()
      .lazy
      .compactMap(windows.window(by:))
      .first { window in
        guard !window.isMinimized, let frame = window.frame() else { return false }
        return NSScreen.screen(containingLargestIntersectionWith: frame)?.uuid == screen.uuid
      }
  }
}
