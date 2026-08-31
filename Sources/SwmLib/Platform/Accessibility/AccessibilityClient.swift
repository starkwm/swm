import ApplicationServices
import CoreGraphics

/// Thin wrapper around macOS Accessibility APIs used by swm.
public final class AccessibilityClient {
  /// Shared accessibility client.
  public static let shared = AccessibilityClient()

  private init() {}

  /// Prompt for accessibility permission when needed and return current trust status.
  public func askForAccessibilityIfNeeded() -> Bool {
    let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary?
    return AXIsProcessTrustedWithOptions(options)
  }

  /// Return the accessibility application element for a process.
  func applicationElement(for processID: pid_t) -> AXUIElement {
    AXUIElementCreateApplication(processID)
  }

  /// Read a Boolean accessibility attribute.
  func boolAttribute(for element: AXUIElement, attribute: String) -> Bool? {
    guard let number = attributeValue(for: element, attribute: attribute) as? NSNumber else {
      return nil
    }

    return number.boolValue
  }

  /// Read a string accessibility attribute.
  func stringAttribute(for element: AXUIElement, attribute: String) -> String? {
    attributeValue(for: element, attribute: attribute) as? String
  }

  /// Read a point accessibility attribute.
  func pointAttribute(for element: AXUIElement, attribute: String) -> CGPoint? {
    var point = CGPoint.zero

    guard
      let value = axValueAttribute(for: element, attribute: attribute, type: .cgPoint),
      AXValueGetValue(value, .cgPoint, &point)
    else {
      return nil
    }

    return point
  }

  /// Read a size accessibility attribute.
  func sizeAttribute(for element: AXUIElement, attribute: String) -> CGSize? {
    var size = CGSize.zero

    guard
      let value = axValueAttribute(for: element, attribute: attribute, type: .cgSize),
      AXValueGetValue(value, .cgSize, &size)
    else {
      return nil
    }

    return size
  }

  /// Return a frame built from accessibility position and size attributes.
  func frame(for element: AXUIElement) -> CGRect? {
    guard let origin = pointAttribute(for: element, attribute: kAXPositionAttribute as String),
      let size = sizeAttribute(for: element, attribute: kAXSizeAttribute as String)
    else {
      return nil
    }

    return CGRect(origin: origin, size: size)
  }

  /// Return whether an accessibility attribute is settable.
  func isAttributeSettable(_ attribute: String, for element: AXUIElement) -> Bool {
    var settable = DarwinBoolean(false)
    guard AXUIElementIsAttributeSettable(element, attribute as CFString, &settable) == .success
    else {
      return false
    }

    return settable.boolValue
  }

  /// Set a raw accessibility attribute value.
  @discardableResult
  func setAttributeValue(_ value: CFTypeRef, for element: AXUIElement, attribute: String) -> Bool {
    AXUIElementSetAttributeValue(element, attribute as CFString, value) == .success
  }

  /// Set a point accessibility attribute.
  func setPoint(_ point: CGPoint, for element: AXUIElement, attribute: String) -> Bool {
    var pointValue = point

    guard let value = AXValueCreate(.cgPoint, &pointValue) else { return false }

    return AXUIElementSetAttributeValue(element, attribute as CFString, value) == .success
  }

  /// Set a size accessibility attribute.
  func setSize(_ size: CGSize, for element: AXUIElement, attribute: String) -> Bool {
    var sizeValue = size

    guard let value = AXValueCreate(.cgSize, &sizeValue) else { return false }

    return AXUIElementSetAttributeValue(element, attribute as CFString, value) == .success
  }

  /// Perform an accessibility action on an element.
  @discardableResult
  func performAction(_ action: String, for element: AXUIElement) -> Bool {
    AXUIElementPerformAction(element, action as CFString) == .success
  }

  /// Return accessibility window elements owned by an application element.
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

  /// Return the focused window element for an application element.
  func focusedWindowElement(for element: AXUIElement) -> AXUIElement? {
    guard
      let value = attributeValue(for: element, attribute: kAXFocusedWindowAttribute as String),
      CFGetTypeID(value) == AXUIElementGetTypeID()
    else {
      return nil
    }

    return (value as! AXUIElement)
  }

  /// Return the Core Graphics window ID for an accessibility element, or zero on failure.
  func windowID(for element: AXUIElement) -> CGWindowID {
    var identifier: CGWindowID = 0
    let result: ApplicationServices.AXError = _AXUIElementGetWindow(element, &identifier)

    guard result == .success else { return 0 }

    return identifier
  }

  /// Return the Core Graphics window ID for an accessibility element when available.
  func optionalWindowID(for element: AXUIElement) -> CGWindowID? {
    let windowID = windowID(for: element)
    return windowID != 0 ? windowID : nil
  }

  /// Return the owning process ID for an accessibility element.
  func processID(for element: AXUIElement) -> pid_t? {
    var pid: pid_t = 0
    guard AXUIElementGetPid(element, &pid) == .success else { return nil }
    return pid
  }

  /// Return the accessibility subrole for an element.
  func subrole(for element: AXUIElement) -> String? {
    stringAttribute(for: element, attribute: kAXSubroleAttribute as String)
  }

  /// Return whether an element is marked as the main window.
  func isMainWindow(_ element: AXUIElement) -> Bool {
    boolAttribute(for: element, attribute: kAXMainAttribute as String) ?? false
  }

  /// Return whether an element has the accessibility window role.
  func isWindow(_ element: AXUIElement) -> Bool {
    stringAttribute(for: element, attribute: kAXRoleAttribute as String) == kAXWindowRole
  }

  /// Return whether an application has enhanced accessibility UI enabled.
  func enhancedUIEnabled(for element: AXUIElement, attribute: String) -> Bool {
    boolAttribute(for: element, attribute: attribute) ?? false
  }

  /// Create an accessibility observer for a process.
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

  /// Add an accessibility notification to an observer.
  func addNotification(
    observer: AXObserver,
    element: AXUIElement,
    notification: String,
    context: UnsafeMutableRawPointer?
  ) -> ApplicationServices.AXError {
    AXObserverAddNotification(observer, element, notification as CFString, context)
  }

  /// Remove an accessibility notification from an observer.
  func removeNotification(observer: AXObserver, element: AXUIElement, notification: String) {
    AXObserverRemoveNotification(observer, element, notification as CFString)
  }

  /// Read an untyped accessibility attribute value.
  private func attributeValue(for element: AXUIElement, attribute: String) -> AnyObject? {
    var value: AnyObject?

    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
      return nil
    }

    return value
  }

  /// Read an accessibility value after verifying its Core Foundation and payload types.
  private func axValueAttribute(
    for element: AXUIElement,
    attribute: String,
    type: AXValueType
  ) -> AXValue? {
    guard
      let value = attributeValue(for: element, attribute: attribute),
      CFGetTypeID(value) == AXValueGetTypeID()
    else {
      return nil
    }

    let axValue = value as! AXValue
    return AXValueGetType(axValue) == type ? axValue : nil
  }
}

extension AccessibilityClient: @unchecked Sendable {}
