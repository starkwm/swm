import Foundation
import Testing

@testable import SwmLib

@Suite("IPC wire schema")
struct IPCWireSchemaTests {
  @Test("request matches the legacy JSON schema")
  func requestFixture() throws {
    let fixture =
      #"{"args":["main display","--title=A window with spaces"],"command":"focus","domain":"window","id":"request-id","version":1}"#
    let request = IPCRequest(
      id: "request-id",
      domain: .window,
      command: "focus",
      args: ["main display", "--title=A window with spaces"]
    )
    #expect(try encode(request) == fixture)
    #expect(try JSONDecoder().decode(IPCRequest.self, from: Data(fixture.utf8)) == request)
  }

  @Test("responses match legacy JSON, including absent success errorCode")
  func responseFixtures() throws {
    #expect(
      try encode(IPCResponse.success(id: "request-id", message: "ok"))
        == #"{"id":"request-id","message":"ok","ok":true}"#
    )
    #expect(
      try encode(
        IPCResponse.failure(
          id: "request-id",
          message: "invalid message",
          errorCode: .invalidRequest
        )
      )
        == #"{"errorCode":"invalidRequest","id":"request-id","message":"invalid message","ok":false}"#
    )
  }

  private func encode(_ value: some Encodable) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return String(decoding: try encoder.encode(value), as: UTF8.self)
  }
}
