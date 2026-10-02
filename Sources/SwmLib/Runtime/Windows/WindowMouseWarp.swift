import AppKit

/// Moves the cursor into an on-screen window without posting a mouse event.
@MainActor
struct WindowMouseWarp {
  static let shared = WindowMouseWarp()

  let isOnScreen: (CGWindowID) -> Bool

  private let cursorWindowID: () -> CGWindowID?
  private let displayFrames: () -> [CGRect]
  private let warpCursor: (CGPoint) -> CGError

  init(
    isOnScreen: @escaping (CGWindowID) -> Bool = { windowID in
      let info =
        CGWindowListCopyWindowInfo(.optionIncludingWindow, windowID)
        as? [[String: Any]]
      return info?.first?[kCGWindowIsOnscreen as String] as? Bool == true
    },
    displayFrames: @escaping () -> [CGRect] = { NSScreen.screens.map(\.axFrame) },
    warpCursor: @escaping (CGPoint) -> CGError = { CGWarpMouseCursorPosition($0) },
    cursorWindowID: @escaping () -> CGWindowID? = {
      guard let point = CGEvent(source: nil)?.location else { return nil }
      return WindowServerClient.shared.frontmostWindowID(at: point)
    }
  ) {
    self.isOnScreen = isOnScreen
    self.displayFrames = displayFrames
    self.warpCursor = warpCursor
    self.cursorWindowID = cursorWindowID
  }

  /// Start cursor navigation from the managed window beneath it, falling back to focus.
  func sourceWindow(
    windowByID: (CGWindowID) -> Window?,
    focusedWindow: () throws -> Window
  ) throws -> Window {
    if let windowID = cursorWindowID(),
      let window = windowByID(windowID),
      !window.isMinimized, isOnScreen(windowID)
    {
      return window
    }

    return try focusedWindow()
  }

  /// Reject unavailable destinations before moving the cursor.
  func warp(windowID: CGWindowID, frame: CGRect?) throws {
    guard isOnScreen(windowID) else {
      throw IPCCommandError.invalidRequest("window is not on screen: \(windowID)")
    }

    guard let frame,
      frame.origin.x.isFinite, frame.origin.y.isFinite,
      frame.size.width.isFinite, frame.size.height.isFinite,
      frame.size.width > 0, frame.size.height > 0,
      frame.midX.isFinite, frame.midY.isFinite
    else {
      throw IPCCommandError.internalError("could not read window frame: \(windowID)")
    }

    let frames = displayFrames()
    var destination = CGPoint(x: frame.midX, y: frame.midY)

    if !frames.contains(where: { $0.contains(destination) }) {
      guard
        let visibleFrame = frames.map({ $0.intersection(frame) })
          .filter({ !$0.isNull && !$0.isEmpty })
          .max(by: { $0.width * $0.height < $1.width * $1.height })
      else {
        throw IPCCommandError.invalidRequest("window has no on-screen bounds: \(windowID)")
      }

      destination = CGPoint(x: visibleFrame.midX, y: visibleFrame.midY)
    }

    let result = warpCursor(destination)

    guard result == .success else {
      throw IPCCommandError.internalError(
        "could not warp mouse cursor to window: \(windowID); Core Graphics error: \(result.rawValue)"
      )
    }
  }
}
