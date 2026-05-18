import Foundation

/// Main-thread dispatcher for runtime events.
public final class EventManager {
  /// Shared event manager used by model callbacks.
  public static let shared = EventManager()

  private let queue = OperationQueue.main
  private var configuration: Configuration?

  private init() {}

  /// Configure the managers used to handle runtime events.
  public func configure(
    workspace: Workspace,
    processManager: ProcessManager,
    windowManager: WindowManager,
    spaceManager: SpaceManager,
    displayManager: DisplayManager
  ) {
    configuration = Configuration(
      workspace: workspace,
      processManager: processManager,
      windowManager: windowManager,
      spaceManager: spaceManager,
      displayManager: displayManager
    )
  }

  /// Enqueue a runtime event for main-thread handling.
  func post(_ event: RuntimeEvent) {
    queue.addOperation {
      self.handle(event)
    }
  }

  /// Dispatch an event to its domain-specific lifecycle handler.
  private func handle(_ event: RuntimeEvent) {
    guard let configuration else {
      preconditionFailure("EventManager must be configured before handling events")
    }

    let payloadBeforeHandling =
      if case .window(.destroyed(let window)) = event {
        windowPayload(event: .windowDestroyed, window: window, configuration: configuration)
      } else {
        Optional<SignalPayload>.none
      }

    switch event {
    case .application(let event):
      ApplicationLifecycleHandler(
        workspace: configuration.workspace,
        processManager: configuration.processManager,
        windowManager: configuration.windowManager
      ).handle(event)

    case .window(let event):
      WindowLifecycleHandler(windowManager: configuration.windowManager).handle(event)

    case .space(let event):
      SpaceLifecycleHandler(
        spaceManager: configuration.spaceManager,
        windowManager: configuration.windowManager
      ).handle(event)

    case .display(let event):
      DisplayLifecycleHandler(displayManager: configuration.displayManager).handle(event)
    }

    if let payload = signalPayload(
      event,
      configuration: configuration,
      payloadBeforeHandling: payloadBeforeHandling
    ) {
      SignalManager.shared.emit(payload)
    }
  }

  /// Build a signal payload from the runtime event and current state.
  private func signalPayload(
    _ event: RuntimeEvent,
    configuration: Configuration,
    payloadBeforeHandling: SignalPayload?
  ) -> SignalPayload? {
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
      return windowPayload(
        event: .windowCreated,
        windowID: windowID,
        configuration: configuration
      )

    case .window(.destroyed):
      return payloadBeforeHandling

    case .window(.focused(let windowID)):
      return windowPayload(
        event: .windowFocused,
        windowID: windowID,
        active: true,
        configuration: configuration
      )

    case .window(.moved(let windowID)):
      return windowPayload(
        event: .windowMoved,
        windowID: windowID,
        configuration: configuration
      )

    case .window(.resized(let windowID)):
      return windowPayload(
        event: .windowResized,
        windowID: windowID,
        configuration: configuration
      )

    case .window(.minimized(let window)):
      return windowPayload(event: .windowMinimized, window: window, configuration: configuration)

    case .window(.deminimized(let window)):
      return windowPayload(event: .windowDeminimized, window: window, configuration: configuration)

    case .space(.changed(let space)):
      let spaces = SpaceManager.all()
      return .spaceChanged(
        space: space,
        currentIndex: spaces.firstIndex(where: { $0.id == space.id }),
        recentSpaceID: configuration.spaceManager.lastActiveSpaceID,
        recentIndex: configuration.spaceManager.lastActiveSpaceID.flatMap { recentID in
          spaces.firstIndex { $0.id == recentID }
        }
      )

    case .display(.changed):
      return .displayChanged(
        currentID: configuration.displayManager.currentActiveDisplayID,
        recentID: configuration.displayManager.lastActiveDisplayID
      )

    case .display(.added(let displayID)):
      return displayPayload(
        event: .displayAdded,
        displayID: displayID,
        configuration: configuration
      )

    case .display(.removed(let displayID)):
      return displayPayload(
        event: .displayRemoved,
        displayID: displayID,
        configuration: configuration
      )

    case .display(.moved(let displayID)):
      return displayPayload(
        event: .displayMoved,
        displayID: displayID,
        configuration: configuration
      )

    case .display(.resized(let displayID)):
      return displayPayload(
        event: .displayResized,
        displayID: displayID,
        configuration: configuration
      )
    }
  }

  /// Build a window signal payload for the current known state.
  private func windowPayload(
    event: SignalEvent,
    windowID: UInt32,
    active: Bool? = nil,
    configuration: Configuration
  ) -> SignalPayload {
    .window(
      event: event,
      windowID: windowID,
      window: configuration.windowManager.window(by: windowID),
      active: active ?? (configuration.windowManager.currentFocusedWindowID == windowID)
    )
  }

  /// Build a window signal payload for an event that still has a window reference.
  private func windowPayload(
    event: SignalEvent,
    window: Window,
    configuration: Configuration
  ) -> SignalPayload {
    .window(
      event: event,
      windowID: window.id,
      window: window,
      active: configuration.windowManager.currentFocusedWindowID == window.id
    )
  }

  /// Build a display signal payload for CoreGraphics reconfiguration callbacks.
  private func displayPayload(
    event: SignalEvent,
    displayID: UInt32,
    configuration: Configuration
  ) -> SignalPayload {
    .display(
      event: event,
      displayID: displayID,
      currentID: configuration.displayManager.currentActiveDisplayID,
      recentID: configuration.displayManager.lastActiveDisplayID
    )
  }
}

extension EventManager: @unchecked Sendable {}

/// Manager dependencies required by the event dispatcher.
private struct Configuration {
  let workspace: Workspace
  let processManager: ProcessManager
  let windowManager: WindowManager
  let spaceManager: SpaceManager
  let displayManager: DisplayManager
}
