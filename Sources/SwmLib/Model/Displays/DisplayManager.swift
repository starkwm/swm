import Foundation

public final class DisplayManager {
  private static func resolveActiveDisplayID() -> String? {
    WindowServerClient.shared.screenID(
      forSpaceID: Space.active().id,
      connectionID: Space.connection
    )
  }

  public var currentActiveDisplayID: String? {
    lock.withLock {
      activeDisplayState.current
    }
  }

  public var lastActiveDisplayID: String? {
    lock.withLock {
      activeDisplayState.last
    }
  }

  private let lock = NSLock()

  private var activeDisplayState: ActiveDisplayState

  public init() {
    activeDisplayState = ActiveDisplayState(
      current: Self.resolveActiveDisplayID(),
      last: nil
    )
  }

  func activeDisplayDidChange() {
    guard let activeDisplayID = Self.resolveActiveDisplayID() else { return }

    lock.withLock {
      guard activeDisplayID != activeDisplayState.current else { return }

      activeDisplayState = ActiveDisplayState(
        current: activeDisplayID,
        last: activeDisplayState.current
      )
    }
  }

}

extension DisplayManager: @unchecked Sendable {}

private struct ActiveDisplayState {
  var current: String?
  var last: String?
}
