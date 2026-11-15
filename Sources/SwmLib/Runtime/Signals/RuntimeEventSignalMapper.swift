import CoreGraphics

@MainActor
struct RuntimeEventSignalMapper {
  let windows: Windows

  let spaces: Spaces

  let displays: Displays

  private let hasSubscribers: (SignalEvent) -> Bool

  init(
    windows: Windows,
    spaces: Spaces,
    displays: Displays,
    hasSubscribers: @escaping (SignalEvent) -> Bool = { _ in true }
  ) {
    self.windows = windows
    self.spaces = spaces
    self.displays = displays
    self.hasSubscribers = hasSubscribers
  }

  func payload(beforeHandling event: RuntimeEvent) -> SignalPayload? {
    guard case .window(.destroyed(let window)) = event else { return nil }

    return windowPayload(
      event: .windowDestroyed,
      windowID: window.id,
      window: window
    )
  }

  func payload(afterHandling event: RuntimeEvent) -> SignalPayload? {
    switch event {
    case .application(.launched), .application(.terminated):
      return nil

    case .application(.frontSwitched(let process)):
      return .application(
        event: .applicationFrontSwitched,
        processID: process.pid,
        app: process.name,
        active: true
      )

    case .window(.created(_, let windowID)):
      return windowPayload(event: .windowCreated, windowID: windowID)

    case .window(.destroyed), .window(.titleChanged):
      return nil

    case .window(.focused(let windowID)):
      return windowPayload(event: .windowFocused, windowID: windowID, active: true)

    case .window(.moved(let windowID)):
      return windowPayload(event: .windowMoved, windowID: windowID)

    case .window(.resized(let windowID)):
      return windowPayload(event: .windowResized, windowID: windowID)

    case .window(.minimized(let window)):
      return windowPayload(event: .windowMinimized, windowID: window.id, window: window)

    case .window(.deminimized(let window)):
      return windowPayload(event: .windowDeminimized, windowID: window.id, window: window)

    case .space(.unavailable):
      return nil

    case .space(.changed(let space)):
      let allSpaceIDs = WindowServerClient.shared.allSpaceIDs()
      return .spaceChanged(
        space: space,
        currentIndex: allSpaceIDs.firstIndex(of: space.id).map { $0 + 1 },
        recentSpaceID: spaces.lastActiveSpaceID,
        recentIndex: spaces.lastActiveSpaceID.flatMap { recentID in
          allSpaceIDs.firstIndex(of: recentID).map { $0 + 1 }
        }
      )

    case .display(.changed):
      return .displayChanged(
        currentID: displays.currentActiveDisplayID,
        recentID: displays.lastActiveDisplayID
      )

    case .display(.added(let displayID)):
      return displayPayload(event: .displayAdded, displayID: displayID)

    case .display(.removed(let displayID)):
      return displayPayload(event: .displayRemoved, displayID: displayID)

    case .display(.moved(let displayID)):
      return displayPayload(event: .displayMoved, displayID: displayID)

    case .display(.resized(let displayID)):
      return displayPayload(event: .displayResized, displayID: displayID)
    }
  }

  private func windowPayload(
    event: SignalEvent,
    windowID: CGWindowID,
    window: Window? = nil,
    active: Bool? = nil
  ) -> SignalPayload? {
    guard hasSubscribers(event) else { return nil }
    return .window(
      event: event,
      windowID: windowID,
      window: window ?? windows.window(by: windowID),
      active: active ?? (windows.currentFocusedWindowID == windowID)
    )
  }

  private func displayPayload(
    event: SignalEvent,
    displayID: CGDirectDisplayID
  ) -> SignalPayload {
    .display(
      event: event,
      displayID: displayID,
      currentID: displays.currentActiveDisplayID,
      recentID: displays.lastActiveDisplayID
    )
  }
}
