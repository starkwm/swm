import AppKit

private let kAXEnhancedUserInterface = "AXEnhancedUserInterface"

public final class Application: NSObject {
  private static let accessibilityClient = AccessibilityClient.shared
  private static let windowServerClient = WindowServerClient.live
  private static let notificationRegistrar = AXNotificationRegistrar<ApplicationNotifications>(
    notifications: applicationNotifications
  )

  public override var description: String {
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

  public init?(for process: Process) {
    element = Self.accessibilityClient.applicationElement(for: process.pid)

    guard let app = NSRunningApplication(processIdentifier: process.pid) else {
      return nil
    }
    application = app

    if let connectionID = Self.windowServerClient.connectionID(
      for: process.psn,
      mainConnectionID: Space.connection
    ) {
      connection = connectionID
    }
  }

  deinit {
    unobserve()
  }

  func observe() -> Result<Void, AccessibilityClientError> {
    switch Self.accessibilityClient.createObserver(
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
        Self.accessibilityClient.addNotification(
          observer: observer,
          element: element,
          notification: notification,
          context: context
        )
      },
      onFailure: { notification, result in
        retryObserving = result == .cannotComplete

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
        Self.accessibilityClient.removeNotification(
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
    Self.windowServerClient.windowIdentifiers(
      connectionID: Space.connection,
      applicationConnectionID: connection,
      spaceIDs: Space.all().map(\.id)
    )
  }

  func windowElements() -> [AXUIElement] {
    Self.accessibilityClient.windowElements(for: element)
  }

  func enhancedUIWorkaround(callback: () -> Void) {
    let enhancedUserInterfaceEnabled = isEnhancedUIEnabled()

    if enhancedUserInterfaceEnabled {
      Self.accessibilityClient.setAttributeValue(
        kCFBooleanFalse,
        for: element,
        attribute: kAXEnhancedUserInterface
      )
    }

    callback()

    if enhancedUserInterfaceEnabled {
      Self.accessibilityClient.setAttributeValue(
        kCFBooleanTrue,
        for: element,
        attribute: kAXEnhancedUserInterface
      )
    }
  }

  private func isEnhancedUIEnabled() -> Bool {
    Self.accessibilityClient.enhancedUIEnabled(
      for: element,
      attribute: kAXEnhancedUserInterface
    )
  }
}

private func accessibilityObserverCallback(
  _ observer: AXObserver,
  _ element: AXUIElement,
  _ notification: CFString,
  _ context: UnsafeMutableRawPointer?
) {
  switch notification as String {
  case kAXCreatedNotification:
    guard let pid = Window.pid(for: element) else { return }
    guard let windowID = Window.validID(for: element) else { return }
    EventManager.shared.post(.window(.created(pid, windowID)))

  case kAXFocusedWindowChangedNotification:
    guard let windowID = Window.validID(for: element) else { return }
    EventManager.shared.post(.window(.focused(windowID)))

  case kAXWindowMovedNotification:
    guard let windowID = Window.validID(for: element) else { return }
    EventManager.shared.post(.window(.moved(windowID)))

  case kAXWindowResizedNotification:
    guard let windowID = Window.validID(for: element) else { return }
    EventManager.shared.post(.window(.resized(windowID)))

  case kAXWindowMiniaturizedNotification:
    guard let context else { return }
    let windowID = CGWindowID(UInt(bitPattern: context))
    guard let window = WindowManager.shared.window(by: windowID) else { return }
    EventManager.shared.post(.window(.minimized(window)))

  case kAXWindowDeminiaturizedNotification:
    guard let context else { return }
    let windowID = CGWindowID(UInt(bitPattern: context))
    guard let window = WindowManager.shared.window(by: windowID) else { return }
    EventManager.shared.post(.window(.deminimized(window)))

  case kAXUIElementDestroyedNotification:
    guard let context else { return }
    let windowID = CGWindowID(UInt(bitPattern: context))
    guard let window = WindowManager.shared.window(by: windowID) else { return }
    EventManager.shared.post(.window(.destroyed(window)))

  default:
    break
  }
}
