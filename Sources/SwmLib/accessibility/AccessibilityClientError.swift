enum AccessibilityClientError: Error, CustomStringConvertible {
  case observerCreationFailed
  case notificationFailed(String)

  var description: String {
    switch self {
    case .observerCreationFailed:
      return "failed to create accessibility observer"
    case .notificationFailed(let message):
      return message
    }
  }
}
