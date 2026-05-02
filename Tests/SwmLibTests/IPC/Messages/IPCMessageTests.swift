import Foundation
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

  @Test("success response has no error code")
  func successResponseHasNoErrorCode() {
    let response = IPCResponse.success(id: "request-id", message: "ok")

    #expect(response.id == "request-id")
    #expect(response.ok)
    #expect(response.message == "ok")
    #expect(response.errorCode == nil)
  }

  @Test("encode appends newline delimiter")
  func encodeAppendsNewlineDelimiter() throws {
    let response = IPCResponse.success(id: "request-id", message: "ok")

    let data = try IPCMessage.encode(response)

    #expect(data.last == UInt8(ascii: "\n"))
  }

  @Test("decode accepts frame without trailing newline")
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
      _ = try IPCRequest.make(domain: .config, arguments: [])
      Issue.record("Expected missing command error")
    } catch let error as IPCRequestError {
      #expect(error.description == "missing command for config")
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }
}
