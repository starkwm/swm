import Foundation
import Testing

@testable import SwmLib

@Suite("IPCMessage")
struct IPCMessageTests {
  @Test("encode: appends newline delimiter")
  func encodeAppendsNewlineDelimiter() throws {
    let response = IPCResponse.success(id: "request-id", message: "ok")

    let data = try IPCMessage.encode(response)

    #expect(data.last == UInt8(ascii: "\n"))
  }

  @Test("encode/decode: round-trips request arguments")
  func encodeDecodeRoundTripsRequestArguments() throws {
    let request = IPCRequest(
      id: "request-id",
      domain: .window,
      command: "focus",
      args: ["main display", "--title=A window with spaces"]
    )

    let data = try IPCMessage.encode(request)
    let decoded = try IPCMessage.decode(IPCRequest.self, from: data)

    #expect(decoded == request)
  }

  @Test("encode/decode: round-trips failure response")
  func encodeDecodeRoundTripsFailureResponse() throws {
    let response = IPCResponse.failure(
      id: "request-id",
      message: "invalid message",
      errorCode: .invalidRequest
    )

    let data = try IPCMessage.encode(response)
    let decoded = try IPCMessage.decode(IPCResponse.self, from: data)

    #expect(decoded == response)
  }

  @Test("decode: accepts frame without trailing newline")
  func decodeAcceptsFrameWithoutTrailingNewline() throws {
    let request = IPCRequest(
      id: "request-id",
      domain: .config,
      command: "reload",
      args: []
    )

    let data = try JSONEncoder().encode(request)
    let decoded = try IPCMessage.decode(IPCRequest.self, from: data)

    #expect(decoded == request)
  }
}
