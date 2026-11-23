import ApplicationServices
import CHIServices
import CoreGraphics

private let kAXEnhancedUserInterface = "AXEnhancedUserInterface"

public final class AccessibilityClient {
  public static let shared = AccessibilityClient()

  static func frame(from values: [AnyObject]) -> CGRect? {
    guard values.count == 2,
      CFGetTypeID(values[0]) == AXValueGetTypeID(),
      CFGetTypeID(values[1]) == AXValueGetTypeID()
    else { return nil }

    let position = values[0] as! AXValue
    let size = values[1] as! AXValue
    var origin = CGPoint.zero
    var dimensions = CGSize.zero
    guard AXValueGetType(position) == .cgPoint,
      AXValueGetType(size) == .cgSize,
      AXValueGetValue(position, .cgPoint, &origin),
      AXValueGetValue(size, .cgSize, &dimensions)
    else { return nil }

    return CGRect(origin: origin, size: dimensions)
  }

  static let messagingTimeout: Float = 1

  private init() {}

  @discardableResult
  public func limitMessagingTimeout() -> Bool {
    let result = AXUIElementSetMessagingTimeout(
      AXUIElementCreateSystemWide(),
      Self.messagingTimeout
    )
    if result != .success {
      log(
        "could not limit the accessibility messaging timeout: AXError \(result.diagnosticDescription)",
        level: .warn
      )
    }
    return result == .success
  }

  public func askForAccessibilityIfNeeded() -> Bool {
    let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary?
    return AXIsProcessTrustedWithOptions(options)
  }

  func applicationElement(for processID: pid_t) -> AXUIElement {
    AXUIElementCreateApplication(processID)
  }

  func boolAttribute(for element: AXUIElement, attribute: String) -> Bool? {
    guard let number = attributeValue(for: element, attribute: attribute) as? NSNumber else {
      return nil
    }

    return number.boolValue
  }

  func stringAttribute(for element: AXUIElement, attribute: String) -> String? {
    attributeValue(for: element, attribute: attribute) as? String
  }

  func frame(for element: AXUIElement) -> CGRect? {
    var values: CFArray?
    guard
      AXUIElementCopyMultipleAttributeValues(
        element,
        [kAXPositionAttribute, kAXSizeAttribute] as CFArray,
        .stopOnError,
        &values
      ) == .success,
      let values = values as? [AnyObject]
    else {
      return nil
    }

    return Self.frame(from: values)
  }

  func isAttributeSettable(_ attribute: String, for element: AXUIElement) -> Bool {
    attributeSettability(attribute, for: element).value ?? false
  }

  func attributeSettability(_ attribute: String, for element: AXUIElement) -> AccessibilityRead<
    Bool
  > {
    var settable = DarwinBoolean(false)
    let error = AXUIElementIsAttributeSettable(element, attribute as CFString, &settable)
    return AccessibilityRead(error, value: { settable.boolValue }, absent: false)
  }

  @discardableResult
  func setAttributeValue(_ value: CFTypeRef, for element: AXUIElement, attribute: String) -> Bool {
    AXUIElementSetAttributeValue(element, attribute as CFString, value) == .success
  }

  func setPoint(_ point: CGPoint, for element: AXUIElement, attribute: String) -> Bool {
    var pointValue = point

    guard let value = AXValueCreate(.cgPoint, &pointValue) else { return false }

    return AXUIElementSetAttributeValue(element, attribute as CFString, value) == .success
  }

  func setSize(_ size: CGSize, for element: AXUIElement, attribute: String) -> Bool {
    var sizeValue = size

    guard let value = AXValueCreate(.cgSize, &sizeValue) else { return false }

    return AXUIElementSetAttributeValue(element, attribute as CFString, value) == .success
  }

  @discardableResult
  func performAction(_ action: String, for element: AXUIElement) -> Bool {
    AXUIElementPerformAction(element, action as CFString) == .success
  }

  func windowElements(for element: AXUIElement) -> [AXUIElement] {
    var values: AnyObject?

    guard
      AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &values) == .success,
      let windows = values as? [AXUIElement]
    else {
      return []
    }

    return windows
  }

  func focusedWindowElement(for element: AXUIElement) -> AXUIElement? {
    guard
      let value = attributeValue(for: element, attribute: kAXFocusedWindowAttribute as String),
      CFGetTypeID(value) == AXUIElementGetTypeID()
    else {
      return nil
    }

    return (value as! AXUIElement)
  }

  func focusedWindowID(for element: AXUIElement) -> CGWindowID? {
    focusedWindowElement(for: element).flatMap(optionalWindowID(for:))
  }

  func windowID(for element: AXUIElement) -> CGWindowID {
    var identifier: CGWindowID = 0
    let result: ApplicationServices.AXError = _AXUIElementGetWindow(element, &identifier)

    guard result == .success else { return 0 }

    return identifier
  }

  func optionalWindowID(for element: AXUIElement) -> CGWindowID? {
    let windowID = windowID(for: element)
    return windowID != 0 ? windowID : nil
  }

  func processID(for element: AXUIElement) -> pid_t? {
    var pid: pid_t = 0
    guard AXUIElementGetPid(element, &pid) == .success else { return nil }
    return pid
  }

  func subrole(for element: AXUIElement) -> String? {
    stringAttribute(for: element, attribute: kAXSubroleAttribute as String)
  }

  func subroleRead(for element: AXUIElement) -> AccessibilityRead<String?> {
    attributeRead(kAXSubroleAttribute as String, for: element, absent: nil) { $0 as? String }
  }

  func boolAttributeRead(_ attribute: String, for element: AXUIElement) -> AccessibilityRead<Bool> {
    attributeRead(attribute, for: element, absent: false) { ($0 as? NSNumber)?.boolValue ?? false }
  }

  func elementAttributeRead(
    _ attribute: String,
    for element: AXUIElement
  ) -> AccessibilityRead<AXUIElement?> {
    attributeRead(attribute, for: element, absent: nil) { value in
      guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
      return (value as! AXUIElement)
    }
  }

  private func attributeRead<Value>(
    _ attribute: String,
    for element: AXUIElement,
    absent: Value,
    value transform: (AnyObject?) -> Value
  ) -> AccessibilityRead<Value> {
    var value: AnyObject?
    let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    return AccessibilityRead(error, value: { transform(value) }, absent: absent)
  }

  func isWindow(_ element: AXUIElement) -> Bool {
    stringAttribute(for: element, attribute: kAXRoleAttribute as String) == kAXWindowRole
  }

  func disableEnhancedUI(for application: AXUIElement) -> Bool {
    let enabled = boolAttribute(for: application, attribute: kAXEnhancedUserInterface) ?? false
    if enabled {
      setAttributeValue(kCFBooleanFalse, for: application, attribute: kAXEnhancedUserInterface)
    }
    return enabled
  }

  func enableEnhancedUI(for application: AXUIElement) {
    setAttributeValue(kCFBooleanTrue, for: application, attribute: kAXEnhancedUserInterface)
  }

  func createObserver(processID: pid_t, callback: @escaping AXObserverCallback) -> Result<
    AXObserver, AccessibilityClientError
  > {
    var observer: AXObserver?
    let result = AXObserverCreate(processID, callback, &observer)

    guard result == .success, let observer else {
      return .failure(.observerCreationFailed)
    }

    return .success(observer)
  }

  func addNotification(
    observer: AXObserver,
    element: AXUIElement,
    notification: String,
    context: UnsafeMutableRawPointer?
  ) -> ApplicationServices.AXError {
    AXObserverAddNotification(observer, element, notification as CFString, context)
  }

  func removeNotification(observer: AXObserver, element: AXUIElement, notification: String) {
    AXObserverRemoveNotification(observer, element, notification as CFString)
  }

  private func attributeValue(for element: AXUIElement, attribute: String) -> AnyObject? {
    var value: AnyObject?

    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
      return nil
    }

    return value
  }

}

extension AccessibilityClient: @unchecked Sendable {}
