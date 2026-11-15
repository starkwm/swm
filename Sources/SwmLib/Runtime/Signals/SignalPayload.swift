import CoreGraphics

struct SignalPayload: Equatable, Sendable {
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

  @MainActor
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

  static func displayChanged(currentID: String?, recentID: String?) -> SignalPayload {
    SignalPayload(
      event: .displayChanged,
      app: nil,
      title: nil,
      active: nil,
      environment: displayEnvironment(currentID: currentID, recentID: recentID)
    )
  }

  static func display(
    event: SignalEvent,
    displayID: CGDirectDisplayID,
    currentID: String?,
    recentID: String?
  ) -> SignalPayload {
    var environment = displayEnvironment(currentID: currentID, recentID: recentID)
    environment["SWM_EVENT_DISPLAY_ID"] = String(displayID)

    return SignalPayload(
      event: event,
      app: nil,
      title: nil,
      active: nil,
      environment: environment
    )
  }

  private static func displayEnvironment(currentID: String?, recentID: String?) -> [String: String]
  {
    var environment = [String: String]()

    if let currentID {
      environment["SWM_DISPLAY_ID"] = currentID
    }

    if let recentID {
      environment["SWM_RECENT_DISPLAY_ID"] = recentID
    }

    return environment
  }

  let event: SignalEvent

  let app: String?

  let title: String?

  let active: Bool?

  let environment: [String: String]
}
