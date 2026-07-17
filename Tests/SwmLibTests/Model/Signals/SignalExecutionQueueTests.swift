import Foundation
import Testing

@testable import SwmLib

@Suite("SignalExecutionQueue")
struct SignalExecutionQueueTests {
  @Test("enqueue: limits concurrent actions and advances pending jobs")
  func enqueueLimitsConcurrentActionsAndAdvancesPendingJobs() throws {
    let recorder = SignalExecutionRecorder()
    let queue = SignalExecutionQueue(
      maximumConcurrentActions: 2,
      maximumPendingActions: 1,
      executor: recorder.execute
    )

    #expect(queue.enqueue(action: "one", environment: [:]))
    #expect(queue.enqueue(action: "two", environment: [:]))
    #expect(queue.enqueue(action: "three", environment: [:]))
    #expect(queue.enqueue(action: "four", environment: [:]) == false)
    #expect(recorder.startedActions == ["one", "two"])

    try recorder.complete(action: "one")

    #expect(recorder.startedActions == ["one", "two", "three"])
  }
}

private final class SignalExecutionRecorder: @unchecked Sendable {
  private let lock = NSLock()
  private var completions = [String: @Sendable () -> Void]()
  private var actions = [String]()

  var startedActions: [String] {
    lock.withLock { actions }
  }

  func execute(
    action: String,
    environment _: [String: String],
    completion: @escaping @Sendable () -> Void
  ) {
    lock.withLock {
      actions.append(action)
      completions[action] = completion
    }
  }

  func complete(action: String) throws {
    let completion = lock.withLock { completions.removeValue(forKey: action) }
    let requiredCompletion = try #require(completion)
    requiredCompletion()
  }
}
