import Foundation

/// Regex-backed text filter with optional inverted matching.
struct TextFilter: Equatable, @unchecked Sendable {
  /// Original regular-expression pattern.
  let pattern: String

  /// Whether a regex match should reject instead of accept.
  let inverted: Bool

  private let regex: NSRegularExpression

  /// Compile a text filter, rethrowing the regular-expression error for an invalid pattern.
  init(pattern: String, inverted: Bool = false) throws {
    regex = try NSRegularExpression(pattern: pattern)
    self.pattern = pattern
    self.inverted = inverted
  }

  static func == (lhs: TextFilter, rhs: TextFilter) -> Bool {
    lhs.pattern == rhs.pattern && lhs.inverted == rhs.inverted
  }

  /// Return whether the optional value satisfies the filter.
  func matches(_ value: String?) -> Bool {
    guard let value else { return false }

    let range = NSRange(value.startIndex..<value.endIndex, in: value)
    let matched = regex.firstMatch(in: value, range: range) != nil

    return inverted ? !matched : matched
  }
}
