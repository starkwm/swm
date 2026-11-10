import AppKit

/// Window events identified by the notified element's window ID.
private let windowIDEvents: [String: @Sendable (CGWindowID) -> WindowEvent] = [
  kAXFocusedWindowChangedNotification: WindowEvent.focused,
  kAXWindowMovedNotification: WindowEvent.moved,
  kAXTitleChangedNotification: WindowEvent.titleChanged,
  kAXWindowResizedNotification: WindowEvent.resized,
]

/// Window events for the managed window registered as the notification context.
private let observedWindowEvents: [String: @Sendable (Window) -> WindowEvent] = [
  kAXWindowMiniaturizedNotification: WindowEvent.minimized,
  kAXWindowDeminiaturizedNotification: WindowEvent.deminimized,
  kAXUIElementDestroyedNotification: WindowEvent.destroyed,
]

/// Forward accessibility window notifications into swm's event service.
private func accessibilityObserverCallback(
  _ observer: AXObserver,
  _ element: AXUIElement,
  _ notification: CFString,
  _ context: UnsafeMutableRawPointer?
) {
  let notification = notification as String

  if notification == kAXCreatedNotification {
    guard let pid = AccessibilityClient.shared.processID(for: element) else { return }
    guard let windowID = AccessibilityClient.shared.optionalWindowID(for: element) else { return }
    Events.shared.post(.window(.created(pid, windowID)))
  } else if let event = windowIDEvents[notification] {
    guard let windowID = AccessibilityClient.shared.optionalWindowID(for: element) else { return }
    Events.shared.post(.window(event(windowID)))
  } else if let event = observedWindowEvents[notification] {
    guard let context else { return }
    let observation = Unmanaged<WindowObservationContext>.fromOpaque(context).takeUnretainedValue()
    // The observer source is installed only on CFRunLoopGetMain().
    MainActor.assumeIsolated {
      guard let window = observation.window() else { return }
      observation.post(.window(event(window)))
    }
  }
}

/// Runtime model for a single running application.
@MainActor
final class Application: @MainActor CustomStringConvertible, @MainActor Equatable {
  private static let notificationRegistrar = AXNotificationRegistrar(
    notifications: [
      kAXCreatedNotification,
      kAXFocusedWindowChangedNotification,
      kAXWindowMovedNotification,
      kAXWindowResizedNotification,
    ]
  )

  static func == (lhs: Application, rhs: Application) -> Bool {
    lhs === rhs
  }

  /// Debug description including process, app name, and bundle identifier.
  var description: String {
    """
    <Application pid: \(processID), name: \(application.localizedName ?? "-"), \
    bundle: \(application.bundleIdentifier ?? "-")>
    """
  }

  /// Localized application name when available.
  var name: String? {
    application.localizedName
  }

  /// Stable application identifier for rule matching.
  var bundleID: String? { application.bundleIdentifier }

  /// Whether the application currently runs with the accessory activation policy.
  var isAccessory: Bool { application.activationPolicy == .accessory }

  /// Process identifier for the running application.
  let processID: pid_t

  /// Carbon process serial number used by private WindowServer operations.
  private(set) var processSerialNumber: ProcessSerialNumber

  /// Accessibility observer currently registered for this application.
  private(set) var observer: AXObserver?

  /// Whether notification registration should be retried later.
  private(set) var retryObserving = false

  /// Accessibility element for the application process.
  private(set) var element: AXUIElement

  private var application: NSRunningApplication
  private let lookupConnection: () -> Int32?
  private let enumerateWindows: (Int32) -> [CGWindowID]
  private var connection: Int32?
  private var observedNotifications = Set<String>()
  private var observing = false

  /// Create an application model for a process discovered by the process service.
  init?(
    for process: Process,
    lookupConnection: (() -> Int32?)? = nil,
    enumerateWindows: ((Int32) -> [CGWindowID])? = nil
  ) {
    self.lookupConnection =
      lookupConnection ?? {
        WindowServerClient.shared.connectionID(for: process.psn)
      }
    self.enumerateWindows =
      enumerateWindows ?? {
        WindowServerClient.shared.windowIdentifiers(
          applicationConnectionID: $0,
          spaceIDs: WindowServerClient.shared.allSpaceIDs()
        )
      }
    processID = process.pid
    processSerialNumber = process.psn
    element = AccessibilityClient.shared.applicationElement(for: process.pid)

    guard let app = process.application ?? NSRunningApplication(processIdentifier: process.pid)
    else {
      return nil
    }

    application = app
  }

  isolated deinit {
    unobserve()
  }

  /// Register accessibility notifications for this application.
  func observe(
    addNotification: ((String) -> AXError)? = nil
  ) -> Result<Void, AccessibilityClientError> {
    retryObserving = false
    switch AccessibilityClient.shared.createObserver(
      processID: processID,
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
      addNotification: addNotification ?? { notification in
        AccessibilityClient.shared.addNotification(
          observer: observer,
          element: self.element,
          notification: notification,
          context: context
        )
      },
      onFailure: { notification, result in
        retryObserving = retryObserving || result == .cannotComplete
        log(
          "notification \(notification) not added \(self): AXError \(result.diagnosticDescription) (retry: \(retryObserving))",
          level: .warn
        )

        if observationError == nil {
          observationError = .notificationFailed(
            "failed to add notification \(notification): AXError \(result.diagnosticDescription)"
          )
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
  func windowIdentifiers() -> [CGWindowID]? {
    if connection == nil { connection = lookupConnection() }
    guard let connection, connection > 0 else {
      self.connection = nil
      return nil
    }
    return enumerateWindows(connection)
  }

  /// Return accessibility elements for this application's windows.
  func windowElements() -> [AXUIElement] {
    AccessibilityClient.shared.windowElements(for: element)
  }

  /// Return the focused window ID for this application.
  func focusedWindowID() -> CGWindowID? {
    AccessibilityClient.shared.focusedWindowID(for: element)
  }

  /// Activate the application and all of its windows.
  func activate() -> Bool {
    application.activate(options: .activateAllWindows)
  }

  /// Temporarily disable enhanced accessibility UI while running a window operation.
  func enhancedUIWorkaround<Result>(callback: () -> Result) -> Result {
    let restore = AccessibilityClient.shared.disableEnhancedUI(for: element)
    defer { if restore { AccessibilityClient.shared.enableEnhancedUI(for: element) } }
    return callback()
  }
}
