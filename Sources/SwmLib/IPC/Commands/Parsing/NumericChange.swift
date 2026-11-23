public enum NumericChange<Value> {
  case absolute(Value)

  case relative(Value)
}

extension NumericChange: Equatable where Value: Equatable {}
extension NumericChange: Codable where Value: Codable {}
extension NumericChange: Sendable where Value: Sendable {}

extension NumericChange<Int> {
  func applying(to current: Int, context: String) throws -> Int {
    switch self {
    case .absolute(let value):
      return value
    case .relative(let delta):
      let (result, overflow) = current.addingReportingOverflow(delta)
      guard !overflow else {
        throw IPCCommandError.invalidRequest("\(context) adjustment overflows integer range")
      }
      return result
    }
  }
}
