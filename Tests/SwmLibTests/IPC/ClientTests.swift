import Testing

@testable import SwmLib

@Suite("Client")
@MainActor
struct ClientTests {
  @Test("send: rejects mismatched response IDs over a real socket")
  func sendRejectsMismatchedResponseIDsOverARealSocket() async throws {
    let endpoint = try TestEndpoint()
    defer { endpoint.remove() }
    let daemon = Daemon(path: endpoint.path) { _ in .success(id: "wrong", message: "ok") }
    try daemon.run()
    defer { daemon.shutdown() }
    let output = try await runBlocking {
      let result = Client.send(domain: .window, args: ["--focus", "42"]) {
        try Client.exchange($0, path: endpoint.path)
      }
      return (result.ok, result.outputMessage)
    }
    #expect(!output.0)
    #expect(output.1 == "Error: IPC response did not match its request")
  }

  @Test("send: reports a missing daemon at the socket boundary")
  func sendReportsAMissingDaemonAtTheSocketBoundary() async throws {
    let endpoint = try TestEndpoint()
    defer { endpoint.remove() }
    let output = try await runBlocking {
      let result = Client.send(domain: .window, args: ["--focus", "42"]) {
        try Client.exchange($0, path: endpoint.path)
      }
      return (result.ok, result.outputMessage)
    }
    #expect(!output.0)
    #expect(output.1 == "Error: daemon is not running")
  }

  @Test("send: reports a connection closed during dispatch")
  func sendReportsAConnectionClosedDuringDispatch() async throws {
    let endpoint = try TestEndpoint()
    defer { endpoint.remove() }
    weak var reference: Daemon?
    let daemon = Daemon(path: endpoint.path) { request in
      reference?.shutdown()
      return .success(id: request.id, message: "not delivered")
    }
    reference = daemon
    try daemon.run()
    defer { daemon.shutdown() }
    let output = try await runBlocking {
      let result = Client.send(domain: .query, args: ["--windows"]) {
        try Client.exchange($0, path: endpoint.path)
      }
      return (result.ok, result.outputMessage)
    }
    #expect(!output.0)
    #expect(output.1 == "Error: Connection closed or timed out.")
  }
}
