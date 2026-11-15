import Foundation

final class SignalExecutionQueue: @unchecked Sendable {
  typealias Executor =
    @Sendable (
      _ action: String,
      _ environment: [String: String],
      _ completion: @escaping @Sendable () -> Void
    ) -> Void

  private struct Job: Sendable {
    let action: String
    var environment: [String: String]
    let coalescingKey: String?
  }

  private enum EnqueueDisposition {
    case start
    case queued
    case coalesced
    case rejected
  }

  private let lock = NSLock()
  private let maximumConcurrentActions: Int
  private let maximumPendingActions: Int
  private let executor: Executor
  private var pendingJobs = [Job]()
  private var runningActions = 0

  init(
    maximumConcurrentActions: Int = 4,
    maximumPendingActions: Int = 128,
    executor: @escaping Executor = ShellSignalExecutor.execute
  ) {
    precondition(maximumConcurrentActions > 0)
    precondition(maximumPendingActions >= 0)
    self.maximumConcurrentActions = maximumConcurrentActions
    self.maximumPendingActions = maximumPendingActions
    self.executor = executor
  }

  @discardableResult
  func enqueue(
    action: String,
    environment: [String: String],
    coalescingKey: String? = nil
  ) -> Bool {
    let job = Job(action: action, environment: environment, coalescingKey: coalescingKey)
    let disposition = lock.withLock {
      if let coalescingKey,
        let index = pendingJobs.firstIndex(where: { $0.coalescingKey == coalescingKey })
      {
        pendingJobs[index].environment = environment
        return EnqueueDisposition.coalesced
      }

      if runningActions < maximumConcurrentActions {
        runningActions += 1
        return EnqueueDisposition.start
      }

      guard pendingJobs.count < maximumPendingActions else {
        return EnqueueDisposition.rejected
      }
      pendingJobs.append(job)
      return EnqueueDisposition.queued
    }

    switch disposition {
    case .start:
      start(job)
      return true
    case .queued, .coalesced:
      return true
    case .rejected:
      return false
    }
  }

  private func start(_ job: Job) {
    executor(job.action, job.environment) { [weak self] in
      self?.actionDidFinish()
    }
  }

  private func actionDidFinish() {
    let nextJob = lock.withLock { () -> Job? in
      guard runningActions > 0 else { return nil }
      runningActions -= 1

      guard !pendingJobs.isEmpty else { return nil }
      runningActions += 1
      return pendingJobs.removeFirst()
    }

    if let nextJob {
      start(nextJob)
    }
  }
}
