import Foundation

final class EventManager {
  static let shared = EventManager()

  private let queue = OperationQueue.main
  private let workspace = Workspace.shared
  private let windowManager = WindowManager.shared
  private let processLookup = ProcessManager.shared

  private let dispatcher = RuntimeEventDispatcher()

  private lazy var applicationHandler = ApplicationLifecycleHandler(
    workspace: workspace,
    windowManager: windowManager,
    processLookup: processLookup,
    dispatcher: dispatcher,
    postEvent: { [weak self] event in
      self?.post(event)
    }
  )

  private lazy var windowHandler = WindowLifecycleHandler(
    windowManager: windowManager,
    dispatcher: dispatcher
  )

  private lazy var spaceHandler = SpaceLifecycleHandler(
    windowManager: windowManager,
    dispatcher: dispatcher
  )

  private init() {}

  func post(_ event: RuntimeEvent) {
    queue.addOperation {
      self.handle(event)
    }
  }

  private func handle(_ event: RuntimeEvent) {
    switch event {
    case .application(let event):
      applicationHandler.handle(event)
    case .window(let event):
      windowHandler.handle(event)
    case .space(let event):
      spaceHandler.handle(event)
    }
  }
}

extension EventManager: @unchecked Sendable {}
