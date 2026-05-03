import AppKit

public final class Window: NSObject {
  private static let notificationRegistrar = AXNotificationRegistrar<WindowNotifications>(
    notifications: windowNotifications
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

  public override var description: String {
    "<Window id: \(id), title: \(title)>"
  }

  private(set) var element: AXUIElement?
  weak var application: Application?
  private(set) var id: CGWindowID

  private var observedNotifications = WindowNotifications(rawValue: 0)
  private var observationContext: WindowObservationContext?

  init(with element: AXUIElement, for application: Application) {
    self.element = element
    self.application = application
    id = Window.id(for: element)
  }

  deinit {
    unobserve()
    log("window deinit \(self)")
  }

  func invalidate() {
    unobserve()
    element = nil
    application = nil
    id = 0
  }

  public override func isEqual(_ object: Any?) -> Bool {
    guard let window = object as? Self else { return false }

    return id == window.id
  }

  var subrole: String? {
    guard let element else { return nil }
    return AccessibilityClient.shared.subrole(for: element)
  }

  func observe() -> Bool {
    guard let application else { return false }
    guard let observer = application.observer else { return false }
    guard let element else { return false }

    let observationContext = WindowObservationContext(
      windowID: id,
      postEvent: application.post,
      windowLookup: application.window
    )
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

  private var title: String {
    guard let element else { return "" }

    return AccessibilityClient.shared.stringAttribute(
      for: element,
      attribute: kAXTitleAttribute as String
    )
      ?? ""
  }
}

extension Window: @unchecked Sendable {}

final class WindowObservationContext {
  private let windowID: CGWindowID
  private let postEvent: (RuntimeEvent) -> Void
  private let windowLookup: (CGWindowID) -> Window?

  init(
    windowID: CGWindowID,
    postEvent: @escaping (RuntimeEvent) -> Void,
    windowLookup: @escaping (CGWindowID) -> Window?
  ) {
    self.windowID = windowID
    self.postEvent = postEvent
    self.windowLookup = windowLookup
  }

  func post(_ event: RuntimeEvent) {
    postEvent(event)
  }

  func window() -> Window? {
    windowLookup(windowID)
  }
}
