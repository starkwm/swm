enum NumericChange<Value> {
  case absolute(Value)

  case relative(Value)

  init?(_ argument: some StringProtocol, value parse: (String) -> Value?) {
    let parts = argument.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
    guard parts.count == 2, let value = parse(String(parts[1])) else { return nil }

    switch parts[0] {
    case "abs": self = .absolute(value)
    case "rel": self = .relative(value)
    default: return nil
    }
  }
}

extension NumericChange: Equatable where Value: Equatable {}

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
