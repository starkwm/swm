import Foundation

/// How a signal action ended.
enum SignalActionOutcome: Equatable, Sendable {
  /// The action exited, or was ended by a signal it did not get from swm, with this status.
  case exited(Int32)

  /// The action outlived its timeout and swm stopped it.
  case timedOut

  /// The action could not be launched.
  case failedToLaunch
}

/// Default asynchronous `/usr/bin/env sh -c` signal executor.
enum ShellSignalExecutor {
  /// Longest time an action may run before swm stops it and frees its slot.
  static let timeout = Duration.seconds(30)

  /// Time between asking a timed-out action to stop and killing it.
  private static let terminationGracePeriod = Duration.seconds(2)

  /// Execute an action with signal environment variables.
  static func execute(
    action: String,
    environment: [String: String],
    completion: @escaping @Sendable () -> Void
  ) {
    execute(action: action, environment: environment, timeout: timeout) { _ in completion() }
  }

  /// Execute an action, stopping its whole process group if it outlives the timeout.
  ///
  /// Standard input is `/dev/null`, so an action that reads input cannot wait on the daemon's.
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

    // Foundation starts each child in its own process group, so signalling the group also
    // stops commands the shell started.
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

/// Whether swm stopped a signal action, shared between its timer and termination handler.
private final class SignalActionState: @unchecked Sendable {
  private let lock = NSLock()
  private var stopped = false

  var timedOut: Bool {
    get { lock.withLock { stopped } }
    set { lock.withLock { stopped = newValue } }
  }
}

extension Duration {
  /// The duration in seconds as a `TimeInterval`.
  fileprivate var timeInterval: TimeInterval {
    let (seconds, attoseconds) = components
    return TimeInterval(seconds) + TimeInterval(attoseconds) / 1e18
  }
}
