import ApplicationServices
import Testing

@testable import SwmLib

@Suite("AXError")
struct AXErrorTests {
  @Test("diagnosticDescription: distinguishes permission and registration errors")
  func diagnosticDescriptionDistinguishesPermissionAndRegistrationErrors() {
    #expect(AXError.apiDisabled.diagnosticDescription == "apiDisabled (-25211)")
    #expect(AXError.cannotComplete.diagnosticDescription == "cannotComplete (-25204)")
    #expect(
      AXError.notificationUnsupported.diagnosticDescription == "notificationUnsupported (-25207)"
    )
  }
}
