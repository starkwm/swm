import Foundation

/// Default asynchronous `/usr/bin/env sh -c` signal executor.
enum ShellSignalExecutor {
  /// Execute an action with signal environment variables.
  static func execute(action: String, environment: [String: String]) {
    let process = Foundation.Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["sh", "-c", action]

    var mergedEnvironment = ProcessInfo.processInfo.environment
    for (key, value) in environment {
      mergedEnvironment[key] = value
    }
    process.environment = mergedEnvironment

    process.terminationHandler = { process in
      guard process.terminationStatus == 0 else {
        log(
          "signal action exited with status \(process.terminationStatus): \(action)",
          level: .warn
        )
        return
      }
    }

    do {
      try process.run()
    } catch {
      log("could not execute signal action: \(error)", level: .warn)
    }
  }
}
