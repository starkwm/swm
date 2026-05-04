import Foundation

public final class DisplayManager {
  typealias ActiveDisplayIDResolver = @Sendable () -> String?

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
  private let activeDisplayIDResolver: ActiveDisplayIDResolver

  private var activeDisplayState: ActiveDisplayState

  public convenience init() {
    self.init(activeDisplayIDResolver: Self.resolveActiveDisplayID)
  }

  init(activeDisplayIDResolver: @escaping ActiveDisplayIDResolver) {
    self.activeDisplayIDResolver = activeDisplayIDResolver
    activeDisplayState = ActiveDisplayState(
      current: activeDisplayIDResolver(),
      last: nil
    )
  }

  func activeDisplayDidChange() {
    guard let activeDisplayID = activeDisplayIDResolver() else { return }

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
