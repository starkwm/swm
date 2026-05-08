import Foundation

public final class EventManager {
  public static let shared = EventManager()

  private let queue = OperationQueue.main

  private var configuration: Configuration?

  private init() {}

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

  func post(_ event: RuntimeEvent) {
    queue.addOperation {
      self.handle(event)
    }
  }

  private func handle(_ event: RuntimeEvent) {
    guard let configuration else {
      preconditionFailure("EventManager must be configured before handling events")
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
  }
}

extension EventManager: @unchecked Sendable {}

private struct Configuration {
  let workspace: Workspace
  let processManager: ProcessManager
  let windowManager: WindowManager
  let spaceManager: SpaceManager
  let displayManager: DisplayManager
}
