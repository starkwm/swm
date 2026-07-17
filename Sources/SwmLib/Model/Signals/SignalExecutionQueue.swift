import Foundation

/// Bounded queue for asynchronous signal action processes.
final class SignalExecutionQueue: @unchecked Sendable {
  typealias Executor =
    @Sendable (
      _ action: String,
      _ environment: [String: String],
      _ completion: @escaping @Sendable () -> Void
    ) -> Void

  private struct Job: Sendable {
    let action: String
    let environment: [String: String]
  }

  private enum EnqueueDisposition {
    case start
    case queued
    case rejected
  }

  private let lock = NSLock()
  private let maximumConcurrentActions: Int
  private let maximumPendingActions: Int
  private let executor: Executor
  private var pendingJobs = [Job]()
  private var runningActions = 0

  /// Create a queue with bounded running and pending action counts.
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

  /// Enqueue an action, returning false when the pending bound is full.
  @discardableResult
  func enqueue(action: String, environment: [String: String]) -> Bool {
    let job = Job(action: action, environment: environment)
    let disposition = lock.withLock {
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
    case .queued:
      return true
    case .rejected:
      return false
    }
  }

  /// Start one action and advance the queue when it completes.
  private func start(_ job: Job) {
    executor(job.action, job.environment) { [weak self] in
      self?.actionDidFinish()
    }
  }

  /// Release one running slot and start the next pending action.
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
