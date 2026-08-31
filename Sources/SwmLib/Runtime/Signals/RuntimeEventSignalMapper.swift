import CoreGraphics

/// Projects runtime events and current manager state into signal payloads.
@MainActor
struct RuntimeEventSignalMapper {
  /// Window state used to enrich window signals.
  let windowManager: WindowManager

  /// Space state used to describe active-space changes.
  let spaceManager: SpaceManager

  /// Display state used to describe active and reconfigured displays.
  let displayManager: DisplayManager

  /// Capture payload data that lifecycle handling would invalidate.
  func payload(beforeHandling event: RuntimeEvent) -> SignalPayload? {
    guard case .window(.destroyed(let window)) = event else { return nil }

    return windowPayload(
      event: .windowDestroyed,
      windowID: window.id,
      window: window
    )
  }

  /// Build a signal payload from state after lifecycle handling.
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

    case .window(.destroyed):
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

    case .space(.changed(let space)):
      let spaces = SpaceManager.all()
      return .spaceChanged(
        space: space,
        currentIndex: spaces.firstIndex(where: { $0.id == space.id }),
        recentSpaceID: spaceManager.lastActiveSpaceID,
        recentIndex: spaceManager.lastActiveSpaceID.flatMap { recentID in
          spaces.firstIndex { $0.id == recentID }
        }
      )

    case .display(.changed):
      return .displayChanged(
        currentID: displayManager.currentActiveDisplayID,
        recentID: displayManager.lastActiveDisplayID
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

  /// Build a window signal payload from an explicit or currently managed window.
  private func windowPayload(
    event: SignalEvent,
    windowID: CGWindowID,
    window: Window? = nil,
    active: Bool? = nil
  ) -> SignalPayload {
    .window(
      event: event,
      windowID: windowID,
      window: window ?? windowManager.window(by: windowID),
      active: active ?? (windowManager.currentFocusedWindowID == windowID)
    )
  }

  /// Build a display signal payload for a CoreGraphics reconfiguration callback.
  private func displayPayload(
    event: SignalEvent,
    displayID: CGDirectDisplayID
  ) -> SignalPayload {
    .display(
      event: event,
      displayID: displayID,
      currentID: displayManager.currentActiveDisplayID,
      recentID: displayManager.lastActiveDisplayID
    )
  }
}
