import Testing

@testable import SwmLib

@Suite("IPCMessage")
struct IPCMessageTests {
  @Test("request round-trips arguments")
  func requestRoundTripsArguments() throws {
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

  @Test("response round-trips failure")
  func responseRoundTripsFailure() throws {
    let response = IPCResponse.failure(
      id: "request-id",
      message: "invalid message",
      errorCode: .invalidRequest
    )

    let data = try IPCMessage.encode(response)
    let decoded = try IPCMessage.decode(IPCResponse.self, from: data)

    #expect(decoded == response)
  }

  @Test("request builder splits command from arguments")
  func requestBuilderSplitsCommandFromArguments() throws {
    let request = try IPCRequest.make(domain: .window, arguments: ["focus", "main display"])

    #expect(request.version == IPCRequest.currentVersion)
    #expect(request.domain == .window)
    #expect(request.command == "focus")
    #expect(request.args == ["main display"])
  }

  @Test("request builder requires command")
  func requestBuilderRequiresCommand() {
    do {
      _ = try IPCRequest.make(domain: .window, arguments: [])
      Issue.record("Expected missing command error")
    } catch let error as IPCRequestError {
      #expect(error.description == "missing command for window")
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }
}
