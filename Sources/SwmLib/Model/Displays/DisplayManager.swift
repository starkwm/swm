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

  var lastFocusDisplayRequest: FocusDisplayRequest? {
    lock.withLock {
      focusDisplayRequest
    }
  }

  private let lock = NSLock()
  private let activeDisplayIDResolver: ActiveDisplayIDResolver

  private var activeDisplayState: ActiveDisplayState
  private var focusDisplayRequest: FocusDisplayRequest?

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

  func focusDisplay(id: String?, index: Int?, source: String) {
    lock.withLock {
      focusDisplayRequest = FocusDisplayRequest(id: id, index: index, source: source)
    }

    log(
      "focus display requested source: \(source), id: \(id ?? "nil"), index: \(index.map(String.init) ?? "nil")"
    )
  }
}

extension DisplayManager: @unchecked Sendable {}

private struct ActiveDisplayState {
  var current: String?
  var last: String?
}

struct FocusDisplayRequest: Equatable {
  let id: String?
  let index: Int?
  let source: String
}
