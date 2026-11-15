import AppKit

@MainActor
final class Window: @MainActor CustomStringConvertible, @MainActor Equatable {
  private static let notificationRegistrar = AXNotificationRegistrar(
    notifications: [
      kAXUIElementDestroyedNotification,
      kAXWindowMiniaturizedNotification,
      kAXWindowDeminiaturizedNotification,
    ]
  )

  private static let titleNotificationRegistrar = AXNotificationRegistrar(
    notifications: [kAXTitleChangedNotification]
  )

  static func == (lhs: Window, rhs: Window) -> Bool {
    lhs.id == rhs.id
  }

  weak var application: Application?

  var description: String {
    "<Window id: \(id), title: \(title)>"
  }

  var subrole: String? {
    guard let element else { return nil }
    return AccessibilityClient.shared.subrole(for: element)
  }

  var isMinimized: Bool {
    guard let element else { return false }
    return AccessibilityClient.shared.boolAttribute(
      for: element,
      attribute: kAXMinimizedAttribute as String
    ) ?? false
  }

  var isMovable: Bool {
    guard let element else { return false }
    return AccessibilityClient.shared.isAttributeSettable(
      kAXPositionAttribute as String,
      for: element
    )
  }

  var isResizable: Bool {
    guard let element else { return false }
    return AccessibilityClient.shared.isAttributeSettable(kAXSizeAttribute as String, for: element)
  }

  var hasUnavailableTilingFacts: Bool {
    guard let element else { return false }
    return eligibilityReads(for: element).isUnavailable
  }

  private(set) var element: AXUIElement?

  private(set) var id: CGWindowID

  var accessibilityTitle: String? {
    guard let element else { return nil }

    return AccessibilityClient.shared.stringAttribute(
      for: element,
      attribute: kAXTitleAttribute as String
    )
  }

  var title: String {
    accessibilityTitle ?? ""
  }

  private var observedNotifications = Set<String>()
  private var observationContext: WindowObservationContext?

  init(id: CGWindowID, element: AXUIElement? = nil, application: Application? = nil) {
    self.id = id
    self.element = element
    self.application = application
  }

  isolated deinit {
    unobserve()
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
  func focusWithoutRaise(from currentWindow: Window?) -> Bool {
    guard let application else { return false }

    return WindowServerClient.shared.focusWindowWithoutRaise(
      processSerialNumber: application.processSerialNumber,
      windowID: id,
      currentProcessSerialNumber: currentWindow?.application?.processSerialNumber,
      currentWindowID: currentWindow?.id
    )
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

  func frame() -> CGRect? {
    guard let element else { return nil }
    return AccessibilityClient.shared.frame(for: element)
  }

  func tilingSnapshot() -> TilingWindowSnapshot {
    guard let element else {
      return TilingWindowSnapshot(
        id: id,
        displayID: nil,
        subrole: nil,
        isMinimized: false,
        isMovable: false,
        isResizable: false
      )
    }

    let reads = eligibilityReads(for: element)
    return TilingWindowSnapshot(
      id: id,
      displayID: frame().flatMap {
        NSScreen.screen(containingLargestIntersectionWith: $0)?.uuid
      },
      subrole: reads.subrole.value ?? nil,
      isMinimized: isMinimized,
      isMovable: reads.movable.value ?? false,
      isResizable: reads.resizable.value ?? false,
      hasUnavailableFacts: reads.isUnavailable,
      app: application?.name,
      title: title,
      bundleID: application?.bundleID
    )
  }

  func setFrame(_ targetFrame: CGRect, from currentFrame: CGRect) -> WindowFrameMutationResult {
    let result = applyFrame(targetFrame, from: currentFrame)
    guard result == .success, let appliedFrame = frame(),
      !appliedFrame.matches(targetFrame, tolerance: 1)
    else { return result }
    return applyFrame(targetFrame, from: appliedFrame)
  }

  private func applyFrame(
    _ targetFrame: CGRect,
    from currentFrame: CGRect
  ) -> WindowFrameMutationResult {
    guard targetFrame != currentFrame else { return .success }
    guard let application, let element else {
      return targetFrame.size != currentFrame.size ? .resizeFailed : .moveFailed
    }

    return application.enhancedUIWorkaround {
      WindowFrameMutation.apply(
        from: currentFrame,
        to: targetFrame,
        resize: {
          AccessibilityClient.shared.setSize(
            $0,
            for: element,
            attribute: kAXSizeAttribute as String
          )
        },
        move: {
          AccessibilityClient.shared.setPoint(
            $0,
            for: element,
            attribute: kAXPositionAttribute as String
          )
        }
      )
    }
  }

  func observe() -> Bool {
    guard let application else { return false }
    guard let observer = application.observer else { return false }
    guard let element else { return false }

    let observationContext = WindowObservationContext(window: self)
    self.observationContext = observationContext
    let context = Unmanaged.passUnretained(observationContext).toOpaque()

    let addNotification: (String) -> AXError = { notification in
      AccessibilityClient.shared.addNotification(
        observer: observer,
        element: element,
        notification: notification,
        context: context
      )
    }
    var titleTimedOut = false
    _ = Self.titleNotificationRegistrar.observe(
      observedNotifications: &observedNotifications,
      addNotification: addNotification,
      onFailure: { _, result in titleTimedOut = result == .cannotComplete }
    )
    guard !titleTimedOut else { return false }
    return Self.notificationRegistrar.observe(
      observedNotifications: &observedNotifications,
      addNotification: addNotification,
      onFailure: { _, _ in }
    )
  }

  func unobserve() {
    guard let observer = application?.observer else { return }
    guard let element else { return }

    for registrar in [Self.notificationRegistrar, Self.titleNotificationRegistrar] {
      registrar.unobserve(
        observedNotifications: &observedNotifications,
        removeNotification: { notification in
          AccessibilityClient.shared.removeNotification(
            observer: observer,
            element: element,
            notification: notification
          )
        }
      )
    }

    observationContext = nil
  }

  private func eligibilityReads(for element: AXUIElement) -> WindowEligibilityReads {
    let client = AccessibilityClient.shared
    return WindowEligibilityReads(
      subrole: client.subroleRead(for: element),
      movable: client.attributeSettability(kAXPositionAttribute as String, for: element),
      resizable: client.attributeSettability(kAXSizeAttribute as String, for: element)
    )
  }
}

@MainActor
final class WindowObservationContext {
  private weak var observedWindow: Window?

  init(window: Window) {
    observedWindow = window
  }

  func post(_ event: RuntimeEvent) {
    Events.shared.post(event)
  }

  func window() -> Window? {
    observedWindow
  }
}

private struct WindowEligibilityReads {
  let subrole: AccessibilityRead<String?>

  let movable: AccessibilityRead<Bool>

  let resizable: AccessibilityRead<Bool>

  var isUnavailable: Bool {
    subrole.isUnavailable || movable.isUnavailable || resizable.isUnavailable
  }
}
