/// Validates common IPC command argument shapes while preserving command-specific context.
struct IPCArguments {
  private let values: [String]
  private let context: String

  /// Create an argument parser for one command context, such as `space gap`.
  init(_ values: [String], context: String) {
    self.values = values
    self.context = context
  }

  /// Require no arguments.
  func requireEmpty() throws {
    guard values.isEmpty else { throw invalidRequest() }
  }

  /// Require and return exactly one value.
  func requiredValue() throws -> String {
    guard values.count == 1, let value = values.first else { throw invalidRequest() }
    return value
  }

  /// Return zero or one value.
  func optionalValue() throws -> String? {
    guard values.count <= 1 else { throw invalidRequest() }
    return values.first
  }

  /// Parse an optional selector followed by one required value.
  func selectedValue() throws -> (selector: String?, value: String) {
    guard (1...2).contains(values.count), let value = values.last else {
      throw invalidRequest()
    }
    return (selector: values.count == 2 ? values[0] : nil, value: value)
  }

  /// Build the malformed-arguments error for this command context.
  private func invalidRequest() -> IPCCommandError {
    .invalidRequest("invalid \(context) arguments")
  }
}
