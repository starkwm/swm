import Testing

@testable import SwmLib

@Suite("Client")
struct ClientTests {
  @Test("send: accepts matching response")
  func sendAcceptsMatchingResponse() {
    let result = Client.send(message: .window, args: ["--focus", "42"]) { request in
      .success(id: request.id, message: "ok")
    }

    #expect(result.ok)
    #expect(result.outputMessage == "ok")
  }

  @Test("send: rejects missing response")
  func sendRejectsMissingResponse() {
    let result = Client.send(message: .window, args: ["--focus", "42"]) { _ in nil }

    #expect(result.ok == false)
    #expect(result.outputMessage == "error: daemon closed the IPC connection without a response")
  }

  @Test("send: rejects mismatched response ID")
  func sendRejectsMismatchedResponseID() {
    let result = Client.send(message: .window, args: ["--focus", "42"]) { _ in
      .success(id: "another-request", message: "ok")
    }

    #expect(result.ok == false)
    #expect(result.outputMessage == "error: IPC response did not match its request")
  }

  @Test("IPCClientError: describes daemon connection failure")
  func clientErrorDescribesDaemonConnectionFailure() {
    #expect(IPCClientError.daemonNotRunning.description == "daemon is not running")
  }

  @Test("send: presents daemon connection failure")
  func sendPresentsDaemonConnectionFailure() {
    let result = Client.send(message: .window, args: ["--focus", "42"]) { _ in
      throw IPCClientError.daemonNotRunning
    }

    #expect(result.ok == false)
    #expect(result.outputMessage == "error: daemon is not running")
  }
}
