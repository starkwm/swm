import Foundation

final class SignalEmissionRecorder: @unchecked Sendable {
  var actions: [String] { lock.withLock { recordedActions } }
  var environments: [[String: String]] { lock.withLock { recordedEnvironments } }
  private let lock = NSLock()
  private var recordedActions = [String]()
  private var recordedEnvironments = [[String: String]]()

  func execute(
    action: String,
    environment: [String: String],
    completion: @escaping @Sendable () -> Void
  ) {
    lock.withLock {
      recordedActions.append(action)
      recordedEnvironments.append(environment)
    }
    completion()
  }
}
