import AppKit

/// Accessibility notification names matching `ApplicationNotifications`.
let applicationNotifications = [
  kAXCreatedNotification,
  kAXFocusedWindowChangedNotification,
  kAXWindowMovedNotification,
  kAXWindowResizedNotification,
]

private let kAXEnhancedUserInterface = "AXEnhancedUserInterface"

/// Forward accessibility window notifications into swm's event manager.
private func accessibilityObserverCallback(
  _ observer: AXObserver,
  _ element: AXUIElement,
  _ notification: CFString,
  _ context: UnsafeMutableRawPointer?
) {
  switch notification as String {
  case kAXCreatedNotification:
    guard let pid = AccessibilityClient.shared.processID(for: element) else { return }
    guard let windowID = AccessibilityClient.shared.optionalWindowID(for: element) else { return }
    EventManager.shared.post(.window(.created(pid, windowID)))

  case kAXFocusedWindowChangedNotification:
    guard let windowID = AccessibilityClient.shared.optionalWindowID(for: element) else { return }
    EventManager.shared.post(.window(.focused(windowID)))

  case kAXWindowMovedNotification:
    guard let windowID = AccessibilityClient.shared.optionalWindowID(for: element) else { return }
    EventManager.shared.post(.window(.moved(windowID)))

  case kAXWindowResizedNotification:
    guard let windowID = AccessibilityClient.shared.optionalWindowID(for: element) else { return }
    EventManager.shared.post(.window(.resized(windowID)))

  case kAXWindowMiniaturizedNotification:
    guard let context else { return }
    let observation = Unmanaged<WindowObservationContext>.fromOpaque(context).takeUnretainedValue()
    guard let window = observation.window() else { return }
    observation.post(.window(.minimized(window)))

  case kAXWindowDeminiaturizedNotification:
    guard let context else { return }
    let observation = Unmanaged<WindowObservationContext>.fromOpaque(context).takeUnretainedValue()
    guard let window = observation.window() else { return }
    observation.post(.window(.deminimized(window)))

  case kAXUIElementDestroyedNotification:
    guard let context else { return }
    let observation = Unmanaged<WindowObservationContext>.fromOpaque(context).takeUnretainedValue()
    guard let window = observation.window() else { return }
    observation.post(.window(.destroyed(window)))

  default:
    break
  }
}

/// Runtime model for a single running application.
final class Application: NSObject {
  private static let notificationRegistrar = AXNotificationRegistrar<ApplicationNotifications>(
    notifications: applicationNotifications,
    allNotifications: .all
  )

  /// Debug description including process, app name, and bundle identifier.
  override var description: String {
    """
    <Application pid: \(application.processIdentifier), name: \(application.localizedName ?? "-"), \
    bundle: \(application.bundleIdentifier ?? "-")>
    """
  }

  /// Localized application name when available.
  var name: String? {
    application.localizedName
  }

  /// Process identifier for the running application.
  var processID: pid_t {
    application.processIdentifier
  }

  /// Accessibility observer currently registered for this application.
  private(set) var observer: AXObserver?

  /// Whether notification registration should be retried later.
  private(set) var retryObserving = false

  /// Accessibility element for the application process.
  private(set) var element: AXUIElement

  private var application: NSRunningApplication
  private var connection: Int32 = -1
  private var observedNotifications = ApplicationNotifications(rawValue: 0)
  private var observing = false

  /// Create an application model for a process discovered by the process manager.
  init?(for process: Process) {
    element = AccessibilityClient.shared.applicationElement(for: process.pid)

    guard let app = NSRunningApplication(processIdentifier: process.pid) else {
      return nil
    }

    application = app

    if let connectionID = WindowServerClient.shared.connectionID(
      for: process.psn,
    ) {
      connection = connectionID
    }
  }

  deinit {
    unobserve()
  }

  /// Register accessibility notifications for this application.
  func observe() -> Result<Void, AccessibilityClientError> {
    switch AccessibilityClient.shared.createObserver(
      processID: application.processIdentifier,
      callback: accessibilityObserverCallback
    ) {
    case .success(let observer):
      self.observer = observer
    case .failure(let error):
      return .failure(error)
    }

    guard let observer else { return .failure(.observerCreationFailed) }

    let context: UnsafeMutableRawPointer? = Unmanaged.passUnretained(self).toOpaque()
    var observationError: AccessibilityClientError?

    let observedAllNotifications = Self.notificationRegistrar.observe(
      observedNotifications: &observedNotifications,
      addNotification: { notification in
        AccessibilityClient.shared.addNotification(
          observer: observer,
          element: element,
          notification: notification,
          context: context
        )
      },
      onFailure: { notification, result in
        retryObserving = result == .cannotComplete
        log(
          "notification \(notification) not added \(self) (retry: \(retryObserving))",
          level: .warn
        )

        if observationError == nil {
          observationError = .notificationFailed("failed to add notification \(notification)")
        }
      }
    )

    observing = true

    CFRunLoopAddSource(
      CFRunLoopGetMain(),
      AXObserverGetRunLoopSource(observer),
      CFRunLoopMode.defaultMode
    )

    guard observedAllNotifications else {
      return .failure(
        observationError ?? .notificationFailed("not all notifications were added")
      )
    }

    return .success(())
  }

  /// Remove registered accessibility notifications and invalidate the observer source.
  func unobserve() {
    guard let observer else { return }
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

    if observing {
      CFRunLoopSourceInvalidate(AXObserverGetRunLoopSource(observer))
      observing = false
    }

    self.observer = nil
  }

  /// Return window IDs owned by this application on known spaces.
  func windowIdentifiers() -> [CGWindowID] {
    WindowServerClient.shared.windowIdentifiers(
      applicationConnectionID: connection,
      spaceIDs: SpaceManager.all().map(\.id)
    )
  }

  /// Return accessibility elements for this application's windows.
  func windowElements() -> [AXUIElement] {
    AccessibilityClient.shared.windowElements(for: element)
  }

  /// Return the focused window ID for this application.
  func focusedWindowID() -> CGWindowID? {
    guard let element = AccessibilityClient.shared.focusedWindowElement(for: element) else {
      return nil
    }

    return AccessibilityClient.shared.optionalWindowID(for: element)
  }

  /// Activate the application and all of its windows.
  func activate() -> Bool {
    application.activate(options: .activateAllWindows)
  }

  /// Temporarily disable enhanced accessibility UI while running a window operation.
  func enhancedUIWorkaround(callback: () -> Void) {
    let enhancedUserInterfaceEnabled = isEnhancedUIEnabled()

    if enhancedUserInterfaceEnabled {
      AccessibilityClient.shared.setAttributeValue(
        kCFBooleanFalse,
        for: element,
        attribute: kAXEnhancedUserInterface
      )
    }

    callback()

    if enhancedUserInterfaceEnabled {
      AccessibilityClient.shared.setAttributeValue(
        kCFBooleanTrue,
        for: element,
        attribute: kAXEnhancedUserInterface
      )
    }
  }

  /// Return whether the app has enhanced accessibility UI enabled.
  private func isEnhancedUIEnabled() -> Bool {
    AccessibilityClient.shared.enhancedUIEnabled(
      for: element,
      attribute: kAXEnhancedUserInterface
    )
  }
}

/// Accessibility notifications observed for an application.
struct ApplicationNotifications: OptionSet, Sendable {
  /// Observe newly created windows.
  static let windowCreated = ApplicationNotifications(rawValue: 1 << 0)

  /// Observe focused-window changes.
  static let windowFocused = ApplicationNotifications(rawValue: 1 << 1)

  /// Observe window movement.
  static let windowMoved = ApplicationNotifications(rawValue: 1 << 2)

  /// Observe window resizing.
  static let windowResized = ApplicationNotifications(rawValue: 1 << 3)

  /// All application-level notifications currently used by swm.
  static let all: ApplicationNotifications = [
    .windowCreated,
    .windowFocused,
    .windowMoved,
    .windowResized,
  ]

  /// Backing option-set bit field.
  let rawValue: Int8
}
