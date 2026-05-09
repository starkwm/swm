import ArgumentParser
import Foundation

private let logLevelColumnWidth = LogLevel.allCases.map(\.label.count).max()! + 2
private let logConfiguration = LogConfiguration()

/// Write a timestamped log line to standard error when the level is enabled.
func log(_ message: @autoclosure () -> String, level: LogLevel = .debug) {
  guard level >= logConfiguration.minimumLevel() else { return }

  let label = "[\(level.label)]".padding(
    toLength: logLevelColumnWidth,
    withPad: " ",
    startingAt: 0
  )
  let text = "\(Date().ISO8601Format()) \(label) \(message())\n"
  fputs(text, stderr)
  fflush(stderr)
}

/// Set the minimum log level written by `log`.
public func setMinimumLogLevel(_ level: LogLevel) {
  logConfiguration.setMinimumLevel(level)
}

/// Runtime logging severity.
public enum LogLevel: String, CaseIterable, Comparable, ExpressibleByArgument, Sendable {
  /// Detailed diagnostic messages.
  case debug

  /// Informational runtime messages.
  case info

  /// Recoverable problems or unexpected conditions.
  case warn

  /// Runtime failures.
  case error

  /// Compare log levels by severity.
  public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
    lhs.priority < rhs.priority
  }

  /// Uppercase label used in log output.
  var label: String {
    rawValue.uppercased()
  }

  /// Numeric severity used for filtering.
  private var priority: Int {
    switch self {
    case .debug:
      0
    case .info:
      1
    case .warn:
      2
    case .error:
      3
    }
  }
}

/// Thread-safe mutable log configuration.
private final class LogConfiguration: @unchecked Sendable {
  private let lock = NSLock()
  private var level = LogLevel.info

  /// Set the minimum enabled log level.
  func setMinimumLevel(_ level: LogLevel) {
    lock.withLock {
      self.level = level
    }
  }

  /// Return the current minimum enabled log level.
  func minimumLevel() -> LogLevel {
    lock.withLock {
      level
    }
  }
}
