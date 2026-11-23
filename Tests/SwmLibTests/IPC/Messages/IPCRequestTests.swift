import Foundation
import Testing

@testable import SwmLib

@Suite("IPCRequest")
struct IPCRequestTests {
  @Test("encode/decode: round trips typed commands")
  func encodeDecodeRoundTripsTypedCommands() throws {
    let request = IPCRequest(
      id: "request-id",
      command: .window(.move(.recent, .relative(IntPair(10, -20))))
    )
    let json = try wireJSON(request)
    #expect(!json.contains("transaction"))
    #expect(try JSONDecoder().decode(IPCRequest.self, from: Data(json.utf8)) == request)
  }

  @Test("encode/decode: carries a reload transaction only when one is set")
  func encodeDecodeCarriesAReloadTransactionOnlyWhenOneIsSet() throws {
    let request = IPCRequest(
      id: "request-id",
      command: .rule(.add(["manage=off"])),
      transaction: "token"
    )
    let json = try wireJSON(request)
    #expect(json.contains(#""transaction":"token""#))
    #expect(try JSONDecoder().decode(IPCRequest.self, from: Data(json.utf8)) == request)
  }

  private func wireJSON(_ value: some Encodable) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return String(decoding: try encoder.encode(value), as: UTF8.self)
  }
}
