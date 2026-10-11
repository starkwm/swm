import ApplicationServices
import Testing

@testable import SwmLib

@Suite("AXNotificationRegistrar")
struct AXNotificationRegistrarTests {
  @Test("observe: recovers after partial registration and cleanup")
  func observeRecoversAfterPartialRegistrationAndCleanup() {
    let registrar = AXNotificationRegistrar(notifications: ["AXCreated", "AXFocusedWindowChanged"])
    var observed = Set<String>()
    var failures = [AXError]()
    #expect(
      !registrar.observe(
        observedNotifications: &observed,
        addNotification: { $0 == "AXCreated" ? .notificationUnsupported : .success },
        onFailure: { _, error in failures.append(error) }
      )
    )
    #expect(failures == [.notificationUnsupported])
    var removed = [String]()
    registrar.unobserve(
      observedNotifications: &observed,
      removeNotification: { removed.append($0) }
    )
    #expect(removed == ["AXFocusedWindowChanged"])
    #expect(observed.isEmpty)
    #expect(
      registrar.observe(
        observedNotifications: &observed,
        addNotification: { _ in .success },
        onFailure: { _, _ in Issue.record("Retry unexpectedly failed") }
      )
    )
    #expect(observed == ["AXCreated", "AXFocusedWindowChanged"])
  }
}
