import Foundation

public final class EventManager {
  public static let shared = EventManager()

  private let queue = OperationQueue.main

  private let dispatcher = RuntimeEventDispatcher()

  private var applicationHandler: ApplicationLifecycleHandler?
  private var windowHandler: WindowLifecycleHandler?
  private var spaceHandler: SpaceLifecycleHandler?

  private init() {}

  public func configure(
    processLookup: ProcessManager,
    workspace: Workspace,
    windowManager: WindowManager
  ) {
    applicationHandler = ApplicationLifecycleHandler(
      workspace: workspace,
      windowManager: windowManager,
      processLookup: processLookup,
      dispatcher: dispatcher,
      postEvent: { [weak self] event in
        self?.post(event)
      }
    )
    windowHandler = WindowLifecycleHandler(
      windowManager: windowManager,
      dispatcher: dispatcher
    )
    spaceHandler = SpaceLifecycleHandler(
      windowManager: windowManager,
      dispatcher: dispatcher
    )
  }

  func post(_ event: RuntimeEvent) {
    queue.addOperation {
      self.handle(event)
    }
  }

  private func handle(_ event: RuntimeEvent) {
    switch event {
    case .application(let event):
      guard let applicationHandler else {
        preconditionFailure("EventManager must be configured before handling application events")
      }
      applicationHandler.handle(event)
    case .window(let event):
      guard let windowHandler else {
        preconditionFailure("EventManager must be configured before handling window events")
      }
      windowHandler.handle(event)
    case .space(let event):
      guard let spaceHandler else {
        preconditionFailure("EventManager must be configured before handling space events")
      }
      spaceHandler.handle(event)
    }
  }
}

extension EventManager: @unchecked Sendable {}
