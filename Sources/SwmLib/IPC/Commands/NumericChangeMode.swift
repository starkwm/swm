/// Describes whether a numeric command argument replaces or adjusts a value.
enum NumericChangeMode: String {
  /// Treat command values as absolute replacements.
  case absolute = "abs"

  /// Treat command values as relative deltas.
  case relative = "rel"
}

extension NumericChangeMode {
  /// Replace `current` with `value`, or add `value` to it.
  ///
  /// `context` names the command in the error thrown when an adjustment overflows.
  func applying(_ value: Int, to current: Int, context: String) throws -> Int {
    switch self {
    case .absolute:
      return value
    case .relative:
      let (result, overflow) = current.addingReportingOverflow(value)
      guard !overflow else {
        throw IPCCommandError.invalidRequest("\(context) adjustment overflows integer range")
      }
      return result
    }
  }
}
