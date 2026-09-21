import Testing

@testable import SwmLib

@Suite("Client")
struct ClientTests {
  @Test("send: accepts matching response")
  func sendAcceptsMatchingResponse() {
    let result = Client.send(domain: .window, args: ["--focus", "42"]) { request in
      .success(id: request.id, message: "ok")
    }

    #expect(result.ok)
    #expect(result.outputMessage == "ok")
  }

  @Test("send: rejects mismatched response ID")
  func sendRejectsMismatchedResponseID() {
    let result = Client.send(domain: .window, args: ["--focus", "42"]) { _ in
      .success(id: "another-request", message: "ok")
    }

    #expect(result.ok == false)
    #expect(result.outputMessage == "error: IPC response did not match its request")
  }

  @Test("send: presents daemon connection failure")
  func sendPresentsDaemonConnectionFailure() {
    let result = Client.send(domain: .window, args: ["--focus", "42"]) { _ in
      throw IPCClientError.daemonNotRunning
    }

    #expect(result.ok == false)
    #expect(result.outputMessage == "error: daemon is not running")
  }
}
