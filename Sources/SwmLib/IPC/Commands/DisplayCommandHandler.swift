import AppKit

/// Handles display IPC commands.
@MainActor
struct DisplayCommandHandler {
  private let windows: Windows
  private let displays: Displays

  /// Create a display command handler backed by window and display services.
  init(windows: Windows, displays: Displays) {
    self.windows = windows
    self.displays = displays
  }

  /// Dispatch a display IPC request.
  func dispatch(_ request: IPCRequest) -> IPCResponse {
    IPCCommandError.catching(id: request.id) {
      switch request.command {
      case "--focus":
        return try focus(request)
      default:
        throw IPCCommandError.unsupportedCommand("unsupported display command: \(request.command)")
      }
    }
  }

  /// Focus the frontmost window on a display, or the display's desktop when it has none.
  private func focus(_ request: IPCRequest) throws -> IPCResponse {
    let argument = try IPCArguments(request.args, context: "display focus").requiredValue()
    guard let target = DisplayTarget(argument: argument) else {
      throw IPCCommandError.invalidValue("display focus", argument, expected: DisplayTarget.form)
    }

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
      throw IPCCommandError.invalidRequest("could not locate display: \(argument)")
    }

    guard targetID != sourceID else { return .acknowledged(id: request.id) }

    if let window = frontmostWindow(on: screen) {
      try window.focusOrThrow()
      return .acknowledged(id: request.id)
    }

    let center = CGPoint(x: screen.axFrame.midX, y: screen.axFrame.midY)
    CGWarpMouseCursorPosition(center)
    guard WindowServerClient.shared.focusFrontmostWindow(at: center) else {
      throw IPCCommandError.internalError("could not focus display: \(argument)")
    }

    return .acknowledged(id: request.id)
  }

  /// Return the display of the focused window, or of the active Space without one.
  private func currentDisplayID() -> String? {
    if let window = windows.currentFocusedWindowID.flatMap(windows.window(by:)),
      let frame = window.frame(),
      let screen = NSScreen.screen(containingLargestIntersectionWith: frame)
    {
      return screen.uuid
    }

    return Spaces.display(for: Spaces.active())
  }

  /// Return the frontmost managed, visible window on a display.
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
