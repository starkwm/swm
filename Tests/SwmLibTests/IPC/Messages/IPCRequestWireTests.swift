import Foundation
import Testing

@testable import SwmLib

extension IPCRequestTests {
  @Test("encode/decode: preserves the legacy request schema")
  func encodeDecodePreservesTheLegacyRequestSchema() throws {
    let fixture =
      #"{"args":["main display","--title=A window with spaces"],"command":"focus","domain":"window","id":"request-id","version":1}"#
    let request = IPCRequest(
      id: "request-id",
      domain: .window,
      command: "focus",
      args: ["main display", "--title=A window with spaces"]
    )
    #expect(try wireJSON(request) == fixture)
    #expect(try JSONDecoder().decode(IPCRequest.self, from: Data(fixture.utf8)) == request)
  }

  private func wireJSON(_ value: some Encodable) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return String(decoding: try encoder.encode(value), as: UTF8.self)
  }
}
