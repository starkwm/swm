import Foundation

func log(_ message: @autoclosure () -> String, level: LogLevel = .debug) {
  let text = "\(Date().ISO8601Format()) \(level.rawValue): \(message())\n"
  fputs(text, stderr)
  fflush(stderr)
}

enum LogLevel: String {
  case debug = "DEBUG"
  case info = "INFO"
  case warn = "WARN"
  case error = "ERROR"
}
