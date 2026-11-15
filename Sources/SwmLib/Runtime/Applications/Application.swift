import AppKit

private let windowIDEvents: [String: @Sendable (CGWindowID) -> WindowEvent] = [
  kAXFocusedWindowChangedNotification: WindowEvent.focused,
  kAXWindowMovedNotification: WindowEvent.moved,
  kAXTitleChangedNotification: WindowEvent.titleChanged,
  kAXWindowResizedNotification: WindowEvent.resized,
]

private let observedWindowEvents: [String: @Sendable (Window) -> WindowEvent] = [
  kAXWindowMiniaturizedNotification: WindowEvent.minimized,
  kAXWindowDeminiaturizedNotification: WindowEvent.deminimized,
  kAXUIElementDestroyedNotification: WindowEvent.destroyed,
]

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
    MainActor.assumeIsolated {
      guard let window = observation.window() else { return }
      observation.post(.window(event(window)))
    }
  }
}

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

  var description: String {
    """
    <Application pid: \(processID), name: \(application.localizedName ?? "-"), \
    bundle: \(application.bundleIdentifier ?? "-")>
    """
  }

  var name: String? {
    application.localizedName
  }

  var bundleID: String? { application.bundleIdentifier }

  var isAccessory: Bool { application.activationPolicy == .accessory }

  let processID: pid_t

  private(set) var processSerialNumber: ProcessSerialNumber

  private(set) var observer: AXObserver?

  private(set) var retryObserving = false

  private(set) var element: AXUIElement

  private var application: NSRunningApplication
  private let lookupConnection: () -> Int32?
  private let enumerateWindows: (Int32) -> [CGWindowID]
  private var connection: Int32?
  private var observedNotifications = Set<String>()
  private var observing = false

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

  func windowIdentifiers() -> [CGWindowID]? {
    if connection == nil { connection = lookupConnection() }
    guard let connection, connection > 0 else {
      self.connection = nil
      return nil
    }
    return enumerateWindows(connection)
  }

  func windowElements() -> [AXUIElement] {
    AccessibilityClient.shared.windowElements(for: element)
  }

  func focusedWindowID() -> CGWindowID? {
    AccessibilityClient.shared.focusedWindowID(for: element)
  }

  func activate() -> Bool {
    application.activate(options: .activateAllWindows)
  }

  func enhancedUIWorkaround<Result>(callback: () -> Result) -> Result {
    let restore = AccessibilityClient.shared.disableEnhancedUI(for: element)
    defer { if restore { AccessibilityClient.shared.enableEnhancedUI(for: element) } }
    return callback()
  }
}
