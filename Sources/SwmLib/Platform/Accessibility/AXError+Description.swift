import ApplicationServices

extension AXError {
  /// Stable diagnostic name and raw value returned by the accessibility API.
  var diagnosticDescription: String {
    let name: String
    switch self {
    case .success: name = "success"
    case .failure: name = "failure"
    case .illegalArgument: name = "illegalArgument"
    case .invalidUIElement: name = "invalidUIElement"
    case .invalidUIElementObserver: name = "invalidUIElementObserver"
    case .cannotComplete: name = "cannotComplete"
    case .attributeUnsupported: name = "attributeUnsupported"
    case .actionUnsupported: name = "actionUnsupported"
    case .notificationUnsupported: name = "notificationUnsupported"
    case .notImplemented: name = "notImplemented"
    case .notificationAlreadyRegistered: name = "notificationAlreadyRegistered"
    case .apiDisabled: name = "apiDisabled"
    case .noValue: name = "noValue"
    case .parameterizedAttributeUnsupported: name = "parameterizedAttributeUnsupported"
    case .notEnoughPrecision: name = "notEnoughPrecision"
    case .notificationNotRegistered: name = "notificationNotRegistered"
    @unknown default: name = "unknown"
    }
    return "\(name) (\(rawValue))"
  }
}
