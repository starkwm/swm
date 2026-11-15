import Foundation

struct TextFilter: Equatable, @unchecked Sendable {
  let pattern: String

  let inverted: Bool

  private let regex: NSRegularExpression

  init(pattern: String, inverted: Bool = false) throws {
    regex = try NSRegularExpression(pattern: pattern)
    self.pattern = pattern
    self.inverted = inverted
  }

  static func == (lhs: TextFilter, rhs: TextFilter) -> Bool {
    lhs.pattern == rhs.pattern && lhs.inverted == rhs.inverted
  }

  func matches(_ value: String?) -> Bool {
    guard let value else { return false }

    let range = NSRange(value.startIndex..<value.endIndex, in: value)
    let matched = regex.firstMatch(in: value, range: range) != nil

    return inverted ? !matched : matched
  }
}
