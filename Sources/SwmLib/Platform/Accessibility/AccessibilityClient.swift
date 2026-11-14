import ApplicationServices
import CoreGraphics

private let kAXEnhancedUserInterface = "AXEnhancedUserInterface"

/// Thin wrapper around macOS Accessibility APIs used by swm.
public final class AccessibilityClient {
  /// Shared accessibility client.
  public static let shared = AccessibilityClient()

  /// Decode the position and size returned by one batched Accessibility read.
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

  /// Longest time, in seconds, that one Accessibility request may wait for an application.
  ///
  /// Requests run on the main actor, so this bounds how long each one can stall the daemon.
  static let messagingTimeout: Float = 1

  private init() {}

  /// Bound every Accessibility request so an unresponsive application cannot stall the daemon.
  ///
  /// A request that times out fails with `.cannotComplete`, like any other failed read.
  @discardableResult
  public func limitMessagingTimeout() -> Bool {
    // The system-wide element carries the timeout for every element in this process.
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

  /// Read position and size together to avoid a second synchronous app round trip.
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

  /// Return whether an accessibility attribute is settable, or false when that is unknown.
  func isAttributeSettable(_ attribute: String, for element: AXUIElement) -> Bool {
    attributeSettability(attribute, for: element).value ?? false
  }

  /// Read whether an accessibility attribute is settable, keeping failed reads distinct.
  func attributeSettability(_ attribute: String, for element: AXUIElement) -> AccessibilityRead<
    Bool
  > {
    var settable = DarwinBoolean(false)
    let error = AXUIElementIsAttributeSettable(element, attribute as CFString, &settable)
    return AccessibilityRead(error, value: { settable.boolValue }, absent: false)
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

  /// Return the focused window ID for an application element when available.
  func focusedWindowID(for element: AXUIElement) -> CGWindowID? {
    focusedWindowElement(for: element).flatMap(optionalWindowID(for:))
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

  /// Read the accessibility subrole for an element, keeping failed reads distinct from none.
  func subroleRead(for element: AXUIElement) -> AccessibilityRead<String?> {
    var value: AnyObject?
    let error = AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &value)
    return AccessibilityRead(error, value: { value as? String }, absent: nil)
  }

  /// Return whether an element has the accessibility window role.
  func isWindow(_ element: AXUIElement) -> Bool {
    stringAttribute(for: element, attribute: kAXRoleAttribute as String) == kAXWindowRole
  }

  /// Turn off an application's enhanced accessibility UI so window writes apply promptly.
  ///
  /// Return whether it was enabled, and so must be restored with `enableEnhancedUI(for:)`.
  func disableEnhancedUI(for application: AXUIElement) -> Bool {
    let enabled = boolAttribute(for: application, attribute: kAXEnhancedUserInterface) ?? false
    if enabled {
      setAttributeValue(kCFBooleanFalse, for: application, attribute: kAXEnhancedUserInterface)
    }
    return enabled
  }

  /// Turn an application's enhanced accessibility UI back on.
  func enableEnhancedUI(for application: AXUIElement) {
    setAttributeValue(kCFBooleanTrue, for: application, attribute: kAXEnhancedUserInterface)
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

}

extension AccessibilityClient: @unchecked Sendable {}
