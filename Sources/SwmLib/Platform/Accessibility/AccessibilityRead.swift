import ApplicationServices

/// Result of one Accessibility read, keeping a failed read separate from a confirmed value.
enum AccessibilityRead<Value> {
  /// Accessibility answered the read.
  case value(Value)

  /// The read failed without confirming a value, so it may succeed when retried.
  case unavailable

  /// Classify a read from its Accessibility result, mapping confirmed absence to `absent`.
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

  /// Confirmed value, or nil when the read failed.
  var value: Value? {
    guard case .value(let value) = self else { return nil }
    return value
  }

  /// Whether the read failed without confirming a value.
  var isUnavailable: Bool {
    guard case .unavailable = self else { return false }
    return true
  }
}
