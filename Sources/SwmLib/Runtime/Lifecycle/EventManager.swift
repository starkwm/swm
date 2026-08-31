import Foundation

/// Main-thread dispatcher for runtime events.
public final class EventManager {
  /// Shared event manager used by model callbacks.
  public static let shared = EventManager()

  @MainActor
  private var dependencies: EventManagerDependencies?

  private init() {}

  /// Configure the managers used to handle runtime events.
  @MainActor
  public func configure(
    workspace: Workspace,
    processManager: ProcessManager,
    windowManager: WindowManager,
    spaceManager: SpaceManager,
    displayManager: DisplayManager,
    tilingManager: TilingManager
  ) {
    dependencies = EventManagerDependencies(
      workspace: workspace,
      processManager: processManager,
      windowManager: windowManager,
      spaceManager: spaceManager,
      displayManager: displayManager,
      tilingManager: tilingManager
    )
  }

  /// Enqueue a runtime event for main-thread handling.
  func post(_ event: RuntimeEvent) {
    Task { @MainActor in
      self.handle(event)
    }
  }

  /// Capture transient signal state, dispatch the event, and emit its signal.
  @MainActor
  private func handle(_ event: RuntimeEvent) {
    guard let dependencies else {
      preconditionFailure("EventManager must be configured before handling events")
    }

    let signalMapper = RuntimeEventSignalMapper(
      windowManager: dependencies.windowManager,
      spaceManager: dependencies.spaceManager,
      displayManager: dependencies.displayManager
    )
    let payloadBeforeHandling = signalMapper.payload(beforeHandling: event)

    dispatch(event, dependencies: dependencies)

    if let payload = payloadBeforeHandling ?? signalMapper.payload(afterHandling: event) {
      SignalManager.shared.emit(payload)
    }
  }

  /// Dispatch an event to its domain-specific lifecycle handler.
  @MainActor
  private func dispatch(_ event: RuntimeEvent, dependencies: EventManagerDependencies) {
    switch event {
    case .application(let event):
      ApplicationLifecycleHandler(
        workspace: dependencies.workspace,
        processManager: dependencies.processManager,
        windowManager: dependencies.windowManager,
        tilingManager: dependencies.tilingManager
      ).handle(event)

    case .window(let event):
      WindowLifecycleHandler(
        windowManager: dependencies.windowManager,
        tilingManager: dependencies.tilingManager
      ).handle(event)

    case .space(let event):
      SpaceLifecycleHandler(
        spaceManager: dependencies.spaceManager,
        windowManager: dependencies.windowManager,
        tilingManager: dependencies.tilingManager
      ).handle(event)

    case .display(let event):
      DisplayLifecycleHandler(
        displayManager: dependencies.displayManager,
        tilingManager: dependencies.tilingManager
      ).handle(event)
    }
  }
}

extension EventManager: @unchecked Sendable {}

/// Manager dependencies required by the event dispatcher.
private struct EventManagerDependencies {
  let workspace: Workspace
  let processManager: ProcessManager
  let windowManager: WindowManager
  let spaceManager: SpaceManager
  let displayManager: DisplayManager
  let tilingManager: TilingManager
}
