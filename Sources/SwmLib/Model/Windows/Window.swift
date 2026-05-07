import AppKit

final class Window: NSObject {
  private static let notificationRegistrar = AXNotificationRegistrar<WindowNotifications>(
    notifications: windowNotifications,
    allNotifications: .all
  )

  static func id(for element: AXUIElement) -> CGWindowID {
    AccessibilityClient.shared.windowID(for: element)
  }

  static func validID(for element: AXUIElement) -> CGWindowID? {
    let windowID = id(for: element)
    return windowID != 0 ? windowID : nil
  }

  static func isWindow(_ element: AXUIElement) -> Bool {
    AccessibilityClient.shared.isWindow(element)
  }

  static func pid(for element: AXUIElement) -> pid_t? {
    AccessibilityClient.shared.processID(for: element)
  }

  override var description: String {
    "<Window id: \(id), title: \(title)>"
  }

  private(set) var element: AXUIElement?
  weak var application: Application?
  private(set) var id: CGWindowID

  var subrole: String? {
    guard let element else { return nil }
    return AccessibilityClient.shared.subrole(for: element)
  }

  private var title: String {
    guard let element else { return "" }

    return AccessibilityClient.shared.stringAttribute(
      for: element,
      attribute: kAXTitleAttribute as String
    ) ?? ""
  }

  private var observedNotifications = WindowNotifications(rawValue: 0)
  private var observationContext: WindowObservationContext?

  init(with element: AXUIElement, for application: Application) {
    self.element = element
    self.application = application
    id = Window.id(for: element)
  }

  deinit {
    unobserve()
  }

  override func isEqual(_ object: Any?) -> Bool {
    guard let window = object as? Self else { return false }

    return id == window.id
  }

  func invalidate() {
    unobserve()
    element = nil
    application = nil
    id = 0
  }

  @discardableResult
  func focus() -> Bool {
    guard let element else { return false }
    guard let application else { return false }
    guard application.activate() else { return false }

    AccessibilityClient.shared.setAttributeValue(
      element,
      for: application.element,
      attribute: kAXFocusedWindowAttribute as String
    )

    guard
      AccessibilityClient.shared.setAttributeValue(
        kCFBooleanTrue,
        for: element,
        attribute: kAXMainAttribute as String
      )
    else {
      return false
    }

    AccessibilityClient.shared.performAction(kAXRaiseAction as String, for: element)

    return true
  }

  @discardableResult
  func minimize() -> Bool {
    guard let element else { return false }

    return AccessibilityClient.shared.setAttributeValue(
      kCFBooleanTrue,
      for: element,
      attribute: kAXMinimizedAttribute as String
    )
  }

  @discardableResult
  func unminimize() -> Bool {
    guard let element else { return false }

    return AccessibilityClient.shared.setAttributeValue(
      kCFBooleanFalse,
      for: element,
      attribute: kAXMinimizedAttribute as String
    )
  }

  @discardableResult
  func move(to point: CGPoint) -> Bool {
    guard let application else { return false }

    var moved = false
    application.enhancedUIWorkaround {
      guard let element else { return }
      moved = AccessibilityClient.shared.setPoint(
        point,
        for: element,
        attribute: kAXPositionAttribute as String
      )
    }

    return moved
  }

  @discardableResult
  func move(by offset: CGVector) -> Bool {
    guard let frame = frame() else { return false }

    return move(
      to: CGPoint(
        x: frame.origin.x + offset.dx,
        y: frame.origin.y + offset.dy
      )
    )
  }

  @discardableResult
  func resize(to size: CGSize) -> Bool {
    guard let application else { return false }

    var resized = false
    application.enhancedUIWorkaround {
      guard let element else { return }
      resized = AccessibilityClient.shared.setSize(
        size,
        for: element,
        attribute: kAXSizeAttribute as String
      )
    }

    return resized
  }

  @discardableResult
  func resize(by offset: CGVector) -> Bool {
    guard let frame = frame() else { return false }

    return resize(
      to: CGSize(
        width: frame.size.width + offset.dx,
        height: frame.size.height + offset.dy
      )
    )
  }

  func frame() -> CGRect? {
    guard let element else { return nil }
    return AccessibilityClient.shared.frame(for: element)
  }

  func observe() -> Bool {
    guard let application else { return false }
    guard let observer = application.observer else { return false }
    guard let element else { return false }

    let observationContext = WindowObservationContext(window: self)
    self.observationContext = observationContext
    let context = Unmanaged.passUnretained(observationContext).toOpaque()

    return Self.notificationRegistrar.observe(
      observedNotifications: &observedNotifications,
      addNotification: { notification in
        AccessibilityClient.shared.addNotification(
          observer: observer,
          element: element,
          notification: notification,
          context: context
        )
      },
      onFailure: { _, _ in }
    )
  }

  func unobserve() {
    guard let observer = application?.observer else { return }
    guard let element else { return }

    Self.notificationRegistrar.unobserve(
      observedNotifications: &observedNotifications,
      removeNotification: { notification in
        AccessibilityClient.shared.removeNotification(
          observer: observer,
          element: element,
          notification: notification
        )
      }
    )

    observationContext = nil
  }
}

extension Window: @unchecked Sendable {}

final class WindowObservationContext {
  private weak var observedWindow: Window?

  init(window: Window) {
    observedWindow = window
  }

  func post(_ event: RuntimeEvent) {
    EventManager.shared.post(event)
  }

  func window() -> Window? {
    observedWindow
  }
}
