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

  @Test("outputMessage: leaves success messages unchanged")
  func outputMessageLeavesSuccessMessagesUnchanged() {
    let response = IPCResponse.success(id: "request-id", message: #"{"id":1}"#)

    #expect(response.outputMessage == #"{"id":1}"#)
  }

  @Test("outputMessage: prefixes failure messages")
  func outputMessagePrefixesFailureMessages() {
    let response = IPCResponse.failure(
      id: "request-id",
      message: "invalid request",
      errorCode: .invalidRequest
    )

    #expect(response.outputMessage == "error: invalid request")
  }

  @Test("outputMessage: avoids double-prefixing failure messages")
  func outputMessageAvoidsDoublePrefixingFailureMessages() {
    let response = IPCResponse.failure(
      id: "request-id",
      message: "error: invalid request",
      errorCode: .invalidRequest
    )

    #expect(response.outputMessage == "error: invalid request")
  }
}
