import CoreGraphics

/// Stable insertion order for windows managed by one Space layout.
struct OrderedWindowLayout: Equatable {
  /// All retained window leaves, including currently minimized windows.
  private(set) var windowIDs = [CGWindowID]()

  /// Insert a window beside the focused leaf when possible, otherwise append it.
  mutating func insert(_ windowID: CGWindowID, after focusedWindowID: CGWindowID?) {
    guard windowID != 0, !windowIDs.contains(windowID) else { return }

    guard
      let focusedWindowID,
      let focusedIndex = windowIDs.firstIndex(of: focusedWindowID)
    else {
      windowIDs.append(windowID)
      return
    }

    windowIDs.insert(windowID, at: focusedIndex + 1)
  }

  /// Remove a window leaf if present.
  @discardableResult
  mutating func remove(_ windowID: CGWindowID) -> Bool {
    guard let index = windowIDs.firstIndex(of: windowID) else { return false }
    windowIDs.remove(at: index)
    return true
  }

  /// Return retained leaves that currently participate in geometry.
  func activeWindowIDs(excluding minimizedWindowIDs: Set<CGWindowID>) -> [CGWindowID] {
    windowIDs.filter { !minimizedWindowIDs.contains($0) }
  }
}
