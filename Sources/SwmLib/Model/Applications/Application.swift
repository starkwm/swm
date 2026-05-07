import AppKit

private let kAXEnhancedUserInterface = "AXEnhancedUserInterface"

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

final class Application: NSObject {
  private static let notificationRegistrar = AXNotificationRegistrar<ApplicationNotifications>(
    notifications: applicationNotifications,
    allNotifications: .all
  )

  override var description: String {
    """
    <Application pid: \(application.processIdentifier), name: \(application.localizedName ?? "-"), \
    bundle: \(application.bundleIdentifier ?? "-")>
    """
  }

  var name: String? {
    application.localizedName
  }

  var processID: pid_t {
    application.processIdentifier
  }

  private(set) var observer: AXObserver?
  private(set) var retryObserving = false
  private(set) var element: AXUIElement

  private var application: NSRunningApplication
  private var connection: Int32 = -1
  private var observedNotifications = ApplicationNotifications(rawValue: 0)
  private var observing = false

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

  func windowIdentifiers() -> [CGWindowID] {
    WindowServerClient.shared.windowIdentifiers(
      applicationConnectionID: connection,
      spaceIDs: SpaceManager.all().map(\.id)
    )
  }

  func windowElements() -> [AXUIElement] {
    AccessibilityClient.shared.windowElements(for: element)
  }

  func focusedWindowID() -> CGWindowID? {
    guard let element = AccessibilityClient.shared.focusedWindowElement(for: element) else {
      return nil
    }

    return AccessibilityClient.shared.optionalWindowID(for: element)
  }

  func activate() -> Bool {
    application.activate(options: .activateAllWindows)
  }

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

  private func isEnhancedUIEnabled() -> Bool {
    AccessibilityClient.shared.enhancedUIEnabled(
      for: element,
      attribute: kAXEnhancedUserInterface
    )
  }
}
