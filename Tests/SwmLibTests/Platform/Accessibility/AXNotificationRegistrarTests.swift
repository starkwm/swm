import ApplicationServices
import Testing

@testable import SwmLib

@Suite("AXNotificationRegistrar")
struct AXNotificationRegistrarTests {
  @Test("Failed registration can be cleaned up and retried successfully")
  func retryAfterFailure() {
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

  @Test("Diagnostics distinguish permission, transient, and unsupported errors")
  func errorDiagnostics() {
    #expect(AXError.apiDisabled.diagnosticDescription == "apiDisabled (-25211)")
    #expect(AXError.cannotComplete.diagnosticDescription == "cannotComplete (-25204)")
    #expect(
      AXError.notificationUnsupported.diagnosticDescription == "notificationUnsupported (-25207)"
    )
  }
}
