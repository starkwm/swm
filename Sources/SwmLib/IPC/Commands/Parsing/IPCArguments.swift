struct IPCArguments {
  private let values: [String]
  private let context: String

  init(_ values: [String], context: String) {
    self.values = values
    self.context = context
  }

  func requireEmpty() throws {
    guard values.isEmpty else { throw invalidRequest() }
  }

  func requiredValue() throws -> String {
    guard values.count == 1, let value = values.first else { throw invalidRequest() }
    return value
  }

  func optionalValue() throws -> String? {
    guard values.count <= 1 else { throw invalidRequest() }
    return values.first
  }

  func selectedValue() throws -> (selector: String?, value: String) {
    guard (1...2).contains(values.count), let value = values.last else {
      throw invalidRequest()
    }
    return (selector: values.count == 2 ? values[0] : nil, value: value)
  }

  private func invalidRequest() -> IPCCommandError {
    .invalidRequest("invalid \(context) arguments")
  }
}
