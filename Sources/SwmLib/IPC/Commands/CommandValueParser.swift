import CoreGraphics

/// Parses shared command argument values.
enum CommandValueParser {
  /// Accepted form of a ratio change, for error messages.
  static let ratioChangeForm = "abs:<ratio> or rel:<ratio>, such as rel:0.05"

  /// Accepted form of a points change, for error messages.
  static let pointsChangeForm = "abs:<points> or rel:<points>, such as rel:4"

  /// Parse an `abs:value` or `rel:value` points update.
  static func pointsChange(from argument: String) -> (mode: NumericChangeMode, value: Int)? {
    let parts = argument.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
    guard parts.count == 2, let mode = NumericChangeMode(rawValue: parts[0]) else { return nil }
    guard let value = Int(parts[1]) else { return nil }
    return (mode, value)
  }

  /// Parse an `abs:value` or `rel:value` ratio update.
  static func ratioChange(from argument: String) -> LayoutRatioChange? {
    let parts = argument.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
    guard parts.count == 2, let mode = NumericChangeMode(rawValue: parts[0]) else { return nil }
    guard let value = Double(parts[1]), value.isFinite else { return nil }

    switch mode {
    case .absolute:
      return .absolute(CGFloat(value))
    case .relative:
      return .relative(CGFloat(value))
    }
  }

  /// Parse a conventional enabled or disabled value.
  static func boolean(from argument: String) -> Bool? {
    switch argument {
    case "on", "true", "yes", "1":
      return true
    case "off", "false", "no", "0":
      return false
    default:
      return nil
    }
  }
}
