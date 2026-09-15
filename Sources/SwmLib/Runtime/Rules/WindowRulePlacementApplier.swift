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
    topology: SpaceTopology
  ) -> WindowRulePlacementResult {
    guard let window = windows.window(by: windowID), let frame = window.frame(),
      let source = NSScreen.screen(containingLargestIntersectionWith: frame)
    else { return .deferred }
    let screens = NSScreen.arrangedScreens
    let target: NSScreen
    if let display = placement.display {
      guard let targetID = display.resolve(in: screens.map(\.uuid)),
        let screen = screens.first(where: { $0.uuid == targetID })
      else { return .deferred }
      target = screen
    } else {
      target = source
    }

    // The destination's visible normal Space supplies grid padding and gaps.
    guard let layoutID = topology.visibleLayoutIDs.first(where: { $0.displayID == target.uuid })
    else { return .deferred }
    let targetFrame = placement.frame(
      from: frame,
      sourceBounds: source.axVisibleFrame,
      targetBounds: target.axVisibleFrame,
      settings: spaces.settings(for: layoutID.spaceID)
    )
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
  ) -> CGRect {
    if let grid { return grid.frame(in: targetBounds, settings: settings) }
    return WindowDisplayTransfer(
      windowFrame: frame,
      sourceFrame: sourceBounds,
      targetFrame: targetBounds
    ).targetWindowFrame()
  }
}
