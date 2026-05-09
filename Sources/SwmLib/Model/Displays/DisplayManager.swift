import Foundation

/// Tracks the current and previous active display.
public final class DisplayManager {
  /// Display ID for the currently active display.
  var currentActiveDisplayID: String? {
    lock.withLock {
      activeDisplay.current
    }
  }

  /// Display ID for the previously active display.
  var lastActiveDisplayID: String? {
    lock.withLock {
      activeDisplay.last
    }
  }

  private let lock = NSLock()
  private var activeDisplay: TrackedState<String>

  /// Create a display manager seeded from the active space.
  public init() {
    activeDisplay = TrackedState(current: SpaceManager.display(for: SpaceManager.active()))
  }

  /// Update tracked display state after the active space changes.
  func activeDisplayDidChange() {
    guard let activeDisplayID = SpaceManager.display(for: SpaceManager.active()) else { return }

    lock.withLock {
      activeDisplay.update(to: activeDisplayID)
    }
  }
}

extension DisplayManager: @unchecked Sendable {}
