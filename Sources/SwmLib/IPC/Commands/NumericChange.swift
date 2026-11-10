/// An `abs:<value>` replacement or `rel:<value>` adjustment from a command argument.
enum NumericChange<Value> {
  /// Replace the current value.
  case absolute(Value)

  /// Adjust the current value.
  case relative(Value)

  /// Parse `abs:<value>` or `rel:<value>`, reading everything after the mode with `parse`.
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
  /// Replace `current` with the value, or add the value to it.
  ///
  /// `context` names the command in the error thrown when an adjustment overflows.
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
