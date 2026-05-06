import Foundation

private let logLevelColumnWidth = LogLevel.allCases.map(\.rawValue.count).max()! + 2

func log(_ message: @autoclosure () -> String, level: LogLevel = .debug) {
  let label = "[\(level.rawValue)]".padding(
    toLength: logLevelColumnWidth,
    withPad: " ",
    startingAt: 0
  )
  let text = "\(Date().ISO8601Format()) \(label) \(message())\n"
  fputs(text, stderr)
  fflush(stderr)
}

enum LogLevel: String, CaseIterable {
  case debug = "DEBUG"
  case info = "INFO"
  case warn = "WARN"
  case error = "ERROR"
}
