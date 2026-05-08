import ArgumentParser
import Foundation

private let logLevelColumnWidth = LogLevel.allCases.map(\.label.count).max()! + 2
private let logConfiguration = LogConfiguration()

public func setMinimumLogLevel(_ level: LogLevel) {
  logConfiguration.setMinimumLevel(level)
}

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

public enum LogLevel: String, CaseIterable, Comparable, ExpressibleByArgument, Sendable {
  case debug
  case info
  case warn
  case error

  public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
    lhs.priority < rhs.priority
  }

  var label: String {
    rawValue.uppercased()
  }

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

private final class LogConfiguration: @unchecked Sendable {
  private let lock = NSLock()
  private var level = LogLevel.info

  func setMinimumLevel(_ level: LogLevel) {
    lock.withLock {
      self.level = level
    }
  }

  func minimumLevel() -> LogLevel {
    lock.withLock {
      level
    }
  }
}
