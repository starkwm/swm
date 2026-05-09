/// Errors raised while working with accessibility observers.
enum AccessibilityClientError: Error, CustomStringConvertible {
  /// The process accessibility observer could not be created.
  case observerCreationFailed

  /// One or more accessibility notifications could not be registered.
  case notificationFailed(String)

  /// Human-readable accessibility failure description.
  var description: String {
    switch self {
    case .observerCreationFailed:
      return "failed to create accessibility observer"
    case .notificationFailed(let message):
      return message
    }
  }
}
