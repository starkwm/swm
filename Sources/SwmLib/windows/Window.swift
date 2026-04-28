import AppKit

public final class Window: NSObject {
  private static let accessibilityClient = AccessibilityClient.live
  private static let notificationRegistrar = AXNotificationRegistrar<WindowNotifications>(
    notifications: windowNotifications
  )

  static func id(for element: AXUIElement) -> CGWindowID {
    accessibilityClient.windowID(for: element)
  }

  static func validID(for element: AXUIElement) -> CGWindowID? {
    let windowID = id(for: element)
    return windowID != 0 ? windowID : nil
  }

  static func isWindow(_ element: AXUIElement) -> Bool {
    accessibilityClient.isWindow(element)
  }

  static func pid(for element: AXUIElement) -> pid_t? {
    accessibilityClient.processID(for: element)
  }

  public override var description: String {
    "<Window id: \(id), title: \(titleDescription)>"
  }

  private(set) var element: AXUIElement?
  weak var application: Application?
  private(set) var id: CGWindowID

  private var observedNotifications = WindowNotifications(rawValue: 0)

  init(with element: AXUIElement, for application: Application) {
    self.element = element
    self.application = application
    id = Window.id(for: element)
  }

  deinit {
    unobserve()
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
    return Self.accessibilityClient.subrole(for: element)
  }

  func observe() -> Bool {
    guard let observer = application?.observer else { return false }
    guard let element else { return false }

    let context = UnsafeMutableRawPointer(bitPattern: UInt(id))
    return Self.notificationRegistrar.observe(
      observedNotifications: &observedNotifications,
      addNotification: { notification in
        Self.accessibilityClient.addNotification(
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
        Self.accessibilityClient.removeNotification(
          observer: observer,
          element: element,
          notification: notification
        )
      }
    )
  }

  private var titleDescription: String {
    guard let element else { return "" }
    return Self.accessibilityClient.stringAttribute(
      for: element,
      attribute: kAXTitleAttribute as String
    )
      ?? ""
  }
}
