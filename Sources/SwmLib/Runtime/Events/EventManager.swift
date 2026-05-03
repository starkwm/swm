import Foundation

public final class EventManager {
  public static let shared = EventManager()

  private let queue = OperationQueue.main
  private let windowManager = WindowManager.shared

  private let dispatcher = RuntimeEventDispatcher()

  private var applicationHandler: ApplicationLifecycleHandler?

  private lazy var windowHandler = WindowLifecycleHandler(
    windowManager: windowManager,
    dispatcher: dispatcher
  )

  private lazy var spaceHandler = SpaceLifecycleHandler(
    windowManager: windowManager,
    dispatcher: dispatcher
  )

  private init() {}

  public func configure(processLookup: ProcessManager, workspace: Workspace) {
    applicationHandler = ApplicationLifecycleHandler(
      workspace: workspace,
      windowManager: windowManager,
      processLookup: processLookup,
      dispatcher: dispatcher,
      postEvent: { [weak self] event in
        self?.post(event)
      }
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
      windowHandler.handle(event)
    case .space(let event):
      spaceHandler.handle(event)
    }
  }
}

extension EventManager: @unchecked Sendable {}
