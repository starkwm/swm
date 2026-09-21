import AppKit

/// Apply display selection and grid geometry as one frame mutation.
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
    var result = window.setFrame(targetFrame, from: frame)
    if result == .success, let applied = window.frame(), !applied.matches(targetFrame, tolerance: 1)
    {
      result = window.setFrame(targetFrame, from: applied)
    }
    guard result == .success else {
      log("rule placement failed for window \(windowID): \(result)", level: .warn)
      return .failed
    }
    return .applied
  }
}

extension WindowRulePlacement {
  /// Grid coordinates always refer to the destination display.
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
