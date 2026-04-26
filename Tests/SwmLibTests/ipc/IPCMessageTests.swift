import Testing

@testable import SwmLib

@Suite("IPCMessage")
struct IPCMessageTests {
  @Test("request round-trips arguments")
  func requestRoundTripsArguments() throws {
    let request = IPCRequest(
      message: .window,
      args: ["focus", "main display", "--title=A window with spaces"]
    )

    let data = try IPCMessage.encode(request)
    let decoded = try IPCMessage.decode(IPCRequest.self, from: data)

    #expect(decoded == request)
  }

  @Test("response round-trips failure")
  func responseRoundTripsFailure() throws {
    let response = IPCResponse.failure("invalid message")

    let data = try IPCMessage.encode(response)
    let decoded = try IPCMessage.decode(IPCResponse.self, from: data)

    #expect(decoded == response)
  }
}
