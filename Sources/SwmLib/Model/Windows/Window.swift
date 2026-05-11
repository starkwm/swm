import AppKit

/// Accessibility notification names matching `WindowNotifications`.
let windowNotifications = [
  kAXUIElementDestroyedNotification,
  kAXWindowMiniaturizedNotification,
  kAXWindowDeminiaturizedNotification,
]

/// Runtime model for an accessibility-backed window.
final class Window: NSObject {
  private static let notificationRegistrar = AXNotificationRegistrar<WindowNotifications>(
    notifications: windowNotifications,
    allNotifications: .all
  )

  /// Owning application, held weakly to avoid a retain cycle.
  weak var application: Application?

  /// Debug description including window ID and title.
  override var description: String {
    "<Window id: \(id), title: \(title)>"
  }

  /// Accessibility subrole for the window.
  var subrole: String? {
    guard let element else { return nil }
    return AccessibilityClient.shared.subrole(for: element)
  }

  /// Whether accessibility reports the window as minimized.
  var isMinimized: Bool {
    guard let element else { return false }
    return AccessibilityClient.shared.boolAttribute(
      for: element,
      attribute: kAXMinimizedAttribute as String
    ) ?? false
  }

  /// Accessibility element for the window when still valid.
  private(set) var element: AXUIElement?

  /// Core Graphics window ID.
  private(set) var id: CGWindowID

  /// Accessibility title for the window.
  var title: String {
    guard let element else { return "" }

    return AccessibilityClient.shared.stringAttribute(
      for: element,
      attribute: kAXTitleAttribute as String
    ) ?? ""
  }

  private var observedNotifications = WindowNotifications(rawValue: 0)
  private var observationContext: WindowObservationContext?

  /// Create a window model from an accessibility element and owning application.
  init(with element: AXUIElement, for application: Application) {
    self.element = element
    self.application = application
    id = AccessibilityClient.shared.windowID(for: element)
  }

  deinit {
    unobserve()
  }

  /// Compare windows by Core Graphics window ID.
  override func isEqual(_ object: Any?) -> Bool {
    guard let window = object as? Self else { return false }

    return id == window.id
  }

  /// Stop observing and clear references to invalid window state.
  func invalidate() {
    unobserve()
    element = nil
    application = nil
    id = 0
  }

  /// Focus and raise the window through accessibility.
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

  /// Minimize the window through accessibility.
  @discardableResult
  func minimize() -> Bool {
    guard let element else { return false }

    return AccessibilityClient.shared.setAttributeValue(
      kCFBooleanTrue,
      for: element,
      attribute: kAXMinimizedAttribute as String
    )
  }

  /// Restore the window from a minimized state through accessibility.
  @discardableResult
  func unminimize() -> Bool {
    guard let element else { return false }

    return AccessibilityClient.shared.setAttributeValue(
      kCFBooleanFalse,
      for: element,
      attribute: kAXMinimizedAttribute as String
    )
  }

  /// Move the window to an absolute point.
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

  /// Move the window by a relative offset.
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

  /// Resize the window to an absolute size.
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

  /// Resize the window by a relative offset.
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

  /// Return the window frame from accessibility.
  func frame() -> CGRect? {
    guard let element else { return nil }
    return AccessibilityClient.shared.frame(for: element)
  }

  /// Register window-specific accessibility notifications.
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

  /// Remove registered window-specific accessibility notifications.
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

/// Accessibility notifications observed for an individual window.
struct WindowNotifications: OptionSet, Sendable {
  /// Observe window destruction.
  static let windowDestroyed = WindowNotifications(rawValue: 1 << 0)

  /// Observe window minimization.
  static let windowMinimized = WindowNotifications(rawValue: 1 << 1)

  /// Observe restoration from a minimized state.
  static let windowDeminimized = WindowNotifications(rawValue: 1 << 2)

  /// All window-level notifications currently used by swm.
  static let all: WindowNotifications = [
    .windowDestroyed,
    .windowMinimized,
    .windowDeminimized,
  ]

  /// Backing option-set bit field.
  let rawValue: Int8
}

extension Window: @unchecked Sendable {}

/// Weak observation context passed through accessibility notification callbacks.
final class WindowObservationContext {
  private weak var observedWindow: Window?

  /// Create a context for an observed window.
  init(window: Window) {
    observedWindow = window
  }

  /// Post a runtime event for the observed window.
  func post(_ event: RuntimeEvent) {
    EventManager.shared.post(event)
  }

  /// Return the observed window if it is still alive.
  func window() -> Window? {
    observedWindow
  }
}
