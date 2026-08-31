import CoreGraphics

/// Parses shared automatic-layout command values.
enum LayoutCommandParser {
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

  /// Parse a finite absolute ratio.
  static func ratio(from argument: String) -> CGFloat? {
    guard let value = Double(argument), value.isFinite else { return nil }
    return CGFloat(value)
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
