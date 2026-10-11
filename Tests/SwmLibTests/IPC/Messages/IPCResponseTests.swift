import Foundation
import Testing

@testable import SwmLib

@Suite("IPCResponse")
struct IPCResponseTests {
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

  @Test("encode: preserves legacy response JSON and omits success error codes")
  func encodePreservesLegacyResponseJSONAndOmitsSuccessErrorCodes() throws {
    #expect(
      try wireJSON(IPCResponse.success(id: "request-id", message: "ok"))
        == #"{"id":"request-id","message":"ok","ok":true}"#
    )
    #expect(
      try wireJSON(
        IPCResponse.failure(
          id: "request-id",
          message: "invalid message",
          errorCode: .invalidRequest
        )
      )
        == #"{"errorCode":"invalidRequest","id":"request-id","message":"invalid message","ok":false}"#
    )
  }

  private func wireJSON(_ value: some Encodable) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return String(decoding: try encoder.encode(value), as: UTF8.self)
  }
}
