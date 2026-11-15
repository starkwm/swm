import CoreGraphics

enum CommandValueParser {
  static let ratioChangeForm = "abs:<ratio> or rel:<ratio>, such as rel:0.05"

  static let pointsChangeForm = "abs:<points> or rel:<points>, such as rel:4"

  static func ratioChange(from argument: String) -> LayoutRatioChange? {
    NumericChange(argument) { Double($0).flatMap { $0.isFinite ? CGFloat($0) : nil } }
  }

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
