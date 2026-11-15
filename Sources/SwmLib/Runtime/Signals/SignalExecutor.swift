import Foundation

enum SignalActionOutcome: Equatable, Sendable {
  case exited(Int32)

  case timedOut

  case failedToLaunch
}

enum ShellSignalExecutor {
  static let timeout = Duration.seconds(30)

  private static let terminationGracePeriod = Duration.seconds(2)

  static func execute(
    action: String,
    environment: [String: String],
    completion: @escaping @Sendable () -> Void
  ) {
    execute(action: action, environment: environment, timeout: timeout) { _ in completion() }
  }

  static func execute(
    action: String,
    environment: [String: String],
    timeout: Duration,
    completion: @escaping @Sendable (SignalActionOutcome) -> Void
  ) {
    let process = Foundation.Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["sh", "-c", action]
    process.standardInput = FileHandle.nullDevice

    var mergedEnvironment = ProcessInfo.processInfo.environment
    for (key, value) in environment {
      mergedEnvironment[key] = value
    }
    process.environment = mergedEnvironment

    let state = SignalActionState()
    process.terminationHandler = { process in
      let outcome =
        state.timedOut ? SignalActionOutcome.timedOut : .exited(process.terminationStatus)
      if outcome != .exited(0) {
        log("signal action ended with \(outcome): \(action)", level: .warn)
      }
      completion(outcome)
    }

    do {
      try process.run()
    } catch {
      log("could not execute signal action: \(error)", level: .warn)
      completion(.failedToLaunch)
      return
    }

    let processGroup = process.processIdentifier
    DispatchQueue.global().asyncAfter(deadline: .now() + timeout.timeInterval) {
      guard process.isRunning else { return }
      state.timedOut = true
      kill(-processGroup, SIGTERM)
      DispatchQueue.global().asyncAfter(
        deadline: .now() + terminationGracePeriod.timeInterval
      ) {
        guard process.isRunning else { return }
        kill(-processGroup, SIGKILL)
      }
    }
  }
}

private final class SignalActionState: @unchecked Sendable {
  private let lock = NSLock()
  private var stopped = false

  var timedOut: Bool {
    get { lock.withLock { stopped } }
    set { lock.withLock { stopped = newValue } }
  }
}

extension Duration {
  fileprivate var timeInterval: TimeInterval {
    let (seconds, attoseconds) = components
    return TimeInterval(seconds) + TimeInterval(attoseconds) / 1e18
  }
}
