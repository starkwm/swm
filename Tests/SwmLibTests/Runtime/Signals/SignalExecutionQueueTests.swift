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

  @Test("enqueue: replaces a pending action with the same coalescing key")
  func enqueueReplacesAPendingActionWithTheSameCoalescingKey() throws {
    let recorder = SignalExecutionRecorder()
    let queue = SignalExecutionQueue(
      maximumConcurrentActions: 1,
      maximumPendingActions: 2,
      executor: recorder.execute
    )

    #expect(queue.enqueue(action: "moved", environment: ["N": "1"], coalescingKey: "window-1"))
    for n in 2...20 {
      #expect(queue.enqueue(action: "moved", environment: ["N": "\(n)"], coalescingKey: "window-1"))
    }
    #expect(queue.enqueue(action: "moved", environment: ["N": "other"], coalescingKey: "window-2"))

    try recorder.complete(action: "moved")
    try recorder.complete(action: "moved")
    try recorder.complete(action: "moved")

    #expect(recorder.startedEnvironments == [["N": "1"], ["N": "20"], ["N": "other"]])
  }
}

private final class SignalExecutionRecorder: @unchecked Sendable {
  private let lock = NSLock()
  private var completions = [String: [@Sendable () -> Void]]()
  private var actions = [String]()
  private var environments = [[String: String]]()

  var startedActions: [String] {
    lock.withLock { actions }
  }

  var startedEnvironments: [[String: String]] {
    lock.withLock { environments }
  }

  func execute(
    action: String,
    environment: [String: String],
    completion: @escaping @Sendable () -> Void
  ) {
    lock.withLock {
      actions.append(action)
      environments.append(environment)
      completions[action, default: []].append(completion)
    }
  }

  func complete(action: String) throws {
    let completion = lock.withLock { () -> (@Sendable () -> Void)? in
      guard completions[action]?.isEmpty == false else { return nil }
      return completions[action]?.removeFirst()
    }
    let requiredCompletion = try #require(completion)
    requiredCompletion()
  }
}
