import CoreGraphics

/// Parses shared command argument values.
enum CommandValueParser {
  /// Accepted form of a ratio change, for error messages.
  static let ratioChangeForm = "abs:<ratio> or rel:<ratio>, such as rel:0.05"

  /// Accepted form of a points change, for error messages.
  static let pointsChangeForm = "abs:<points> or rel:<points>, such as rel:4"

  /// Parse an `abs:value` or `rel:value` ratio update.
  static func ratioChange(from argument: String) -> LayoutRatioChange? {
    NumericChange(argument) { Double($0).flatMap { $0.isFinite ? CGFloat($0) : nil } }
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
