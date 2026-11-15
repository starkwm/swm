import ApplicationServices

enum AccessibilityRead<Value> {
  case value(Value)

  case unavailable

  init(_ error: AXError, value: () -> Value, absent: Value) {
    switch error {
    case .success:
      self = .value(value())
    case .attributeUnsupported, .noValue, .notImplemented, .illegalArgument:
      self = .value(absent)
    default:
      self = .unavailable
    }
  }

  var value: Value? {
    guard case .value(let value) = self else { return nil }
    return value
  }

  var isUnavailable: Bool {
    guard case .unavailable = self else { return false }
    return true
  }
}
