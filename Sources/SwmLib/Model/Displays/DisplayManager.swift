import Foundation

public final class DisplayManager {
  var currentActiveDisplayID: String? {
    lock.withLock {
      activeDisplay.current
    }
  }

  var lastActiveDisplayID: String? {
    lock.withLock {
      activeDisplay.last
    }
  }

  private let lock = NSLock()

  private var activeDisplay: TrackedState<String>

  public init() {
    activeDisplay = TrackedState(current: SpaceManager.display(for: SpaceManager.active()))
  }

  func activeDisplayDidChange() {
    guard let activeDisplayID = SpaceManager.display(for: SpaceManager.active()) else { return }

    lock.withLock {
      activeDisplay.update(to: activeDisplayID)
    }
  }
}

extension DisplayManager: @unchecked Sendable {}
