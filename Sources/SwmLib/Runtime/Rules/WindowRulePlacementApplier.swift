import AppKit

@MainActor
struct WindowRulePlacementApplier {
  static func displayIDs() -> [String] { NSScreen.arrangedScreens.map(\.uuid) }

  let windows: Windows
  let spaces: Spaces

  func apply(
    _ placement: WindowRulePlacement,
    to windowID: CGWindowID,
    destination: TilingLayoutID
  ) -> WindowRulePlacementResult {
    guard let window = windows.window(by: windowID), let frame = window.frame(),
      let source = NSScreen.screen(containingLargestIntersectionWith: frame)
    else { return .deferred }
    guard let target = NSScreen.arrangedScreens.first(where: { $0.uuid == destination.displayID })
    else { return .deferred }
    guard
      let targetFrame = placement.frame(
        from: frame,
        sourceBounds: source.axVisibleFrame,
        targetBounds: target.axVisibleFrame,
        settings: spaces.settings(for: destination.spaceID)
      )
    else { return .failed }
    let result = window.setFrame(targetFrame, from: frame)
    guard result == .success else {
      log("rule placement failed for window \(windowID): \(result)", level: .warn)
      return .failed
    }
    return .applied
  }

  func move(_ windowID: CGWindowID, toSpace index: Int) async throws {
    guard let window = windows.window(by: windowID) else {
      throw IPCCommandError.invalidRequest("window not found: \(windowID)")
    }
    try await WindowSpaceTransfer.shared.move(window, to: .index(index)) {
      windows.window(by: windowID) === window
    } fit: { frame, targetFrame, destinationID in
      let result = window.setFrame(targetFrame, from: frame)
      guard result == .success else {
        throw IPCCommandError.internalError(
          "window moved to Space \(destinationID), but display placement failed: \(result)"
        )
      }
    }
  }
}

extension WindowRulePlacement {
  func frame(
    from frame: CGRect,
    sourceBounds: CGRect,
    targetBounds: CGRect,
    settings: SpaceSettings
  ) -> CGRect? {
    if let grid { return grid.frame(in: targetBounds, settings: settings) }
    return WindowDisplayTransfer(
      windowFrame: frame,
      sourceFrame: sourceBounds,
      targetFrame: targetBounds
    ).targetWindowFrame()
  }
}
