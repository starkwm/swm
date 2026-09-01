import Foundation

/// Main-thread dispatcher for runtime events.
public final class Events {
  /// Shared event service used by model callbacks.
  public static let shared = Events()

  @MainActor
  private var dependencies: EventDependencies?

  private init() {}

  /// Configure the services used to handle runtime events.
  @MainActor
  public func configure(
    workspace: Workspace,
    processes: Processes,
    windows: Windows,
    spaces: Spaces,
    displays: Displays,
    tiling: Tiling
  ) {
    dependencies = EventDependencies(
      workspace: workspace,
      processes: processes,
      windows: windows,
      spaces: spaces,
      displays: displays,
      tiling: tiling
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
      preconditionFailure("Events must be configured before handling events")
    }

    let signalMapper = RuntimeEventSignalMapper(
      windows: dependencies.windows,
      spaces: dependencies.spaces,
      displays: dependencies.displays
    )
    let payloadBeforeHandling = signalMapper.payload(beforeHandling: event)

    dispatch(event, dependencies: dependencies)

    if let payload = payloadBeforeHandling ?? signalMapper.payload(afterHandling: event) {
      Signals.shared.emit(payload)
    }
  }

  /// Dispatch an event to its domain-specific lifecycle handler.
  @MainActor
  private func dispatch(_ event: RuntimeEvent, dependencies: EventDependencies) {
    switch event {
    case .application(let event):
      ApplicationLifecycleHandler(
        workspace: dependencies.workspace,
        processes: dependencies.processes,
        windows: dependencies.windows,
        tiling: dependencies.tiling
      ).handle(event)

    case .window(let event):
      WindowLifecycleHandler(
        windows: dependencies.windows,
        tiling: dependencies.tiling
      ).handle(event)

    case .space(let event):
      SpaceLifecycleHandler(
        spaces: dependencies.spaces,
        windows: dependencies.windows,
        tiling: dependencies.tiling
      ).handle(event)

    case .display(let event):
      DisplayLifecycleHandler(
        displays: dependencies.displays,
        tiling: dependencies.tiling
      ).handle(event)
    }
  }
}

extension Events: @unchecked Sendable {}

/// Runtime dependencies required by the event dispatcher.
private struct EventDependencies {
  let workspace: Workspace
  let processes: Processes
  let windows: Windows
  let spaces: Spaces
  let displays: Displays
  let tiling: Tiling
}
