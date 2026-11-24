import Foundation

public final class Events: Sendable {
  public static let shared = Events()

  @MainActor
  private var dependencies: EventDependencies?

  private let handleEvent: (@MainActor @Sendable (RuntimeEvent) -> Void)?

  init(handleEvent: (@MainActor @Sendable (RuntimeEvent) -> Void)? = nil) {
    self.handleEvent = handleEvent
  }

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

  func post(_ event: RuntimeEvent) {
    DispatchQueue.main.async {
      if let handleEvent = self.handleEvent {
        handleEvent(event)
      } else {
        self.handle(event)
      }
    }
  }

  @MainActor
  func handle(_ event: RuntimeEvent) {
    guard let dependencies else {
      preconditionFailure("Events must be configured before handling events")
    }

    dispatch(event, dependencies: dependencies)
  }

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

private struct EventDependencies {
  let workspace: Workspace
  let processes: Processes
  let windows: Windows
  let spaces: Spaces
  let displays: Displays
  let tiling: Tiling
}
