import CoreGraphics

/// Runtime event data used to match and execute signals.
struct SignalPayload: Equatable, Sendable {
  /// Build an application payload.
  static func application(
    event: SignalEvent,
    processID: pid_t,
    app: String?,
    active: Bool?
  ) -> SignalPayload {
    return SignalPayload(
      event: event,
      app: app,
      title: nil,
      active: active,
      environment: ["SWM_PROCESS_ID": String(processID)]
    )
  }

  /// Build a window payload.
  static func window(
    event: SignalEvent,
    windowID: CGWindowID,
    window: Window?,
    active: Bool?
  ) -> SignalPayload {
    var environment = ["SWM_WINDOW_ID": String(windowID)]

    if let processID = window?.application?.processID {
      environment["SWM_PROCESS_ID"] = String(processID)
    }

    return SignalPayload(
      event: event,
      app: window?.application?.name,
      title: window?.title,
      active: active,
      environment: environment
    )
  }

  /// Build a space-change payload.
  static func spaceChanged(
    space: Space,
    currentIndex: Int?,
    recentSpaceID: UInt64?,
    recentIndex: Int?
  ) -> SignalPayload {
    var environment = ["SWM_SPACE_ID": String(space.id)]

    if let currentIndex {
      environment["SWM_SPACE_INDEX"] = String(currentIndex)
    }

    if let recentSpaceID {
      environment["SWM_RECENT_SPACE_ID"] = String(recentSpaceID)
    }

    if let recentIndex {
      environment["SWM_RECENT_SPACE_INDEX"] = String(recentIndex)
    }

    return SignalPayload(
      event: .spaceChanged,
      app: nil,
      title: nil,
      active: nil,
      environment: environment
    )
  }

  /// Build a display-change payload.
  static func displayChanged(currentID: String?, recentID: String?) -> SignalPayload {
    var environment = [String: String]()

    if let currentID {
      environment["SWM_DISPLAY_ID"] = currentID
    }

    if let recentID {
      environment["SWM_RECENT_DISPLAY_ID"] = recentID
    }

    return SignalPayload(
      event: .displayChanged,
      app: nil,
      title: nil,
      active: nil,
      environment: environment
    )
  }

  /// Signal event name.
  let event: SignalEvent

  /// Application name used by app filters.
  let app: String?

  /// Window title used by title filters.
  let title: String?

  /// Current/focused state used by active filters.
  let active: Bool?

  /// Environment variables exposed to the shell action.
  let environment: [String: String]
}
