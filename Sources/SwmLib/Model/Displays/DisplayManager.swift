import Foundation

public final class DisplayManager {
  private static func resolveActiveDisplayID() -> String? {
    WindowServerClient.shared.screenID(forSpaceID: SpaceManager.active().id)
  }

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
    activeDisplay = TrackedState(current: Self.resolveActiveDisplayID())
  }

  func activeDisplayDidChange() {
    guard let activeDisplayID = Self.resolveActiveDisplayID() else { return }

    lock.withLock {
      activeDisplay.update(to: activeDisplayID)
    }
  }

}

extension DisplayManager: @unchecked Sendable {}
