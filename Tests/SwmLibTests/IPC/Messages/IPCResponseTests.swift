import Testing

@testable import SwmLib

@Suite("IPCResponse")
struct IPCResponseTests {
  @Test("success: has no error code")
  func successHasNoErrorCode() {
    let response = IPCResponse.success(id: "request-id", message: "ok")

    #expect(response.id == "request-id")
    #expect(response.ok)
    #expect(response.message == "ok")
    #expect(response.errorCode == nil)
  }
}
