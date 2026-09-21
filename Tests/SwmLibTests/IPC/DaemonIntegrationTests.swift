import Darwin
import Foundation
import StarkIPC
import Testing

@testable import SwmLib

// Synchronous clients use GCD threads so they cannot exhaust the cooperative pool
// needed by the server's async handlers when these tests run in parallel.
private func runBlocking<Value: Sendable>(
  _ operation: @escaping @Sendable () throws -> Value
) async throws -> Value {
  try await withCheckedThrowingContinuation { continuation in
    DispatchQueue.global().async {
      continuation.resume(with: Result(catching: operation))
    }
  }
}

// A blocking newline client, matching the old wire exchange without BlueSocket.
private func legacyExchange(path: String, input: Data, endWriting: Bool = false) throws -> Data {
  let fd = try LocalSocket.connect(path: path)
  defer { close(fd) }
  try LocalSocket.send(input, to: fd)
  if endWriting { Darwin.shutdown(fd, SHUT_WR) }
  return try readToEOF(fd)
}

private func readToEOF(_ fd: Int32) throws -> Data {
  var timeout = timeval(tv_sec: 7, tv_usec: 0)
  setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
  var data = Data()
  var buffer = [UInt8](repeating: 0, count: 8192)
  while true {
    let count = recv(fd, &buffer, buffer.count, 0)
    if count < 0 && errno == EINTR { continue }
    guard count >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    if count == 0 { return data }
    data.append(contentsOf: buffer.prefix(count))
  }
}

@Suite("Daemon integration")
@MainActor
struct DaemonIntegrationTests {
  @Test("real socket dispatches on the main actor and preserves command failure IDs")
  func commandDispatch() async throws {
    let endpoint = try TestEndpoint()
    defer { endpoint.remove() }
    var dispatched = false
    let daemon = Daemon(path: endpoint.path) { request in
      MainActor.assertIsolated()
      dispatched = true
      return IPCCommandError.unsupportedCommand("unsupported test command").response(id: request.id)
    }
    try daemon.run()
    defer { daemon.shutdown() }
    let response = try await exchange(path: endpoint.path)
    #expect(dispatched)
    #expect(
      response
        == .failure(
          id: "test-id",
          message: "unsupported test command",
          errorCode: .unsupportedCommand
        )
    )
  }

  @Test("socket requests reach the application dispatcher and update local settings")
  func applicationDispatcher() async throws {
    let endpoint = try TestEndpoint()
    defer { endpoint.remove() }
    let spaces = Spaces(activeSpaceID: nil)
    let dispatcher = IPCCommandDispatcher(
      windows: Windows(workspace: Workspace()),
      spaces: spaces,
      tiling: makeTestTiling(spaces: spaces)
    )
    let daemon = Daemon(path: endpoint.path, dispatch: dispatcher.dispatch)
    try daemon.run()
    defer { daemon.shutdown() }
    let response = try await runBlocking {
      try Client.exchange(
        IPCRequest(id: "setting", domain: .config, command: "window-gap", args: ["17"]),
        path: endpoint.path
      )
    }
    #expect(response == .success(id: "setting", message: "ok"))
    #expect(spaces.settings(for: 42).gap == 17)
  }

  @Test("version validation rejects before command dispatch and preserves the ID")
  func versionValidation() async throws {
    let endpoint = try TestEndpoint()
    defer { endpoint.remove() }
    let daemon = Daemon(path: endpoint.path) { request in
      Issue.record("invalid version reached the dispatcher")
      return .success(id: request.id, message: "unexpected")
    }
    try daemon.run()
    defer { daemon.shutdown() }
    let response = try await exchange(path: endpoint.path, version: 2)
    #expect(response.id == "test-id")
    #expect(response.errorCode == .invalidRequest)
    #expect(response.message == "unsupported IPC request version: 2; expected 1")
  }

  @Test("malformed legacy client input receives invalidRequest and an empty ID")
  func malformedInput() async throws {
    let endpoint = try TestEndpoint()
    defer { endpoint.remove() }
    let daemon = Daemon(path: endpoint.path) { request in
      Issue.record("malformed input reached dispatch")
      return .success(id: request.id, message: "unexpected")
    }
    try daemon.run()
    defer { daemon.shutdown() }
    let response = try await runBlocking {
      let data = try legacyExchange(path: endpoint.path, input: Data("{broken\n".utf8))
      return try JSONDecoder().decode(IPCResponse.self, from: data)
    }
    #expect(!response.ok)
    #expect(response.id == "")
    #expect(response.errorCode == .invalidRequest)
  }

  @Test("old newline client exchanges a golden request with the new server")
  func legacyClient() async throws {
    let endpoint = try TestEndpoint()
    defer { endpoint.remove() }
    let daemon = Daemon(path: endpoint.path) { request in
      #expect(request.domain == .window)
      #expect(request.command == "--focus")
      #expect(request.args == ["42"])
      return .success(id: request.id, message: "ok")
    }
    try daemon.run()
    defer { daemon.shutdown() }
    let response = try await runBlocking {
      let data = try legacyExchange(
        path: endpoint.path,
        input: Data(
          (#"{"version":1,"id":"old-client","domain":"window","command":"--focus","args":["42"]}"#
            + "\n").utf8
        )
      )
      return try JSONDecoder().decode(IPCResponse.self, from: data)
    }
    #expect(response == .success(id: "old-client", message: "ok"))
  }

  @Test("unterminated legacy input is rejected without dispatch")
  func unterminatedInput() async throws {
    let endpoint = try TestEndpoint()
    defer { endpoint.remove() }
    let daemon = Daemon(path: endpoint.path) { request in
      Issue.record("unterminated request reached dispatch")
      return .success(id: request.id, message: "unexpected")
    }
    try daemon.run()
    defer { daemon.shutdown() }
    let data = try await runBlocking {
      try legacyExchange(
        path: endpoint.path,
        input: JSONEncoder().encode(
          IPCRequest(id: "test", domain: .query, command: "windows", args: [])
        ),
        endWriting: true
      )
    }
    #expect(data.isEmpty)
  }

  @Test("query JSON stays sorted and UInt64 identifiers stay exact over transport")
  func queryJSON() async throws {
    let endpoint = try TestEndpoint()
    defer { endpoint.remove() }
    let daemon = Daemon(path: endpoint.path) { request in
      try! .json(
        id: request.id,
        payload: SpaceSerializer(
          id: UInt64.max,
          index: 0,
          type: "user",
          displays: [1],
          windows: [42],
          hasFocus: true,
          isVisible: true,
          isNativeFullscreen: false
        )
      )
    }
    try daemon.run()
    defer { daemon.shutdown() }
    let response = try await exchange(path: endpoint.path)
    #expect(
      response.message
        == #"{"displays":[1],"has-focus":true,"id":18446744073709551615,"index":0,"is-native-fullscreen":false,"is-visible":true,"type":"user","windows":[42]}"#
    )
  }

  @Test("client checks response IDs over a real socket")
  func mismatchedID() async throws {
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
    #expect(output.1 == "error: IPC response did not match its request")
  }

  @Test("connection initialization failures retain the daemon-not-running diagnostic")
  func missingDaemon() async throws {
    let endpoint = try TestEndpoint()
    defer { endpoint.remove() }
    let output = try await runBlocking {
      let result = Client.send(domain: .window, args: ["--focus", "42"]) {
        try Client.exchange($0, path: endpoint.path)
      }
      return (result.ok, result.outputMessage)
    }
    #expect(!output.0)
    #expect(output.1 == "error: daemon is not running")
  }

  @Test("shutdown rejects queued work even when the daemon is restarted")
  func restartRejectsQueuedRequests() async throws {
    let endpoint = try TestEndpoint()
    defer { endpoint.remove() }
    var dispatches = 0
    let daemon = Daemon(path: endpoint.path) { request in
      dispatches += 1
      return .success(id: request.id, message: "ok")
    }
    try daemon.run()
    defer { daemon.shutdown() }
    let fd = try LocalSocket.connect(path: endpoint.path)
    defer { close(fd) }
    try LocalSocket.send(
      Data(
        (#"{"version":1,"id":"queued","domain":"query","command":"windows","args":[]}"# + "\n").utf8
      ),
      to: fd
    )
    // Hold the actor briefly so the transport can queue the decoded request.
    usleep(100_000)
    daemon.shutdown()
    try daemon.run()
    _ = try await runBlocking { try readToEOF(fd) }
    let response = try await exchange(path: endpoint.path)
    #expect(response.ok)
    #expect(dispatches == 1)
  }

  @Test("realistic window queries reach a draining client", arguments: [1, 32, 256])
  func largeQuery(windowCount: Int) async throws {
    let endpoint = try TestEndpoint()
    defer { endpoint.remove() }
    let payload = (0..<windowCount).map { index in
      WindowSerializer(
        id: UInt32(index + 1),
        pid: 123,
        app: "Terminal",
        title: "A realistic window title with spaces",
        frame: nil,
        role: "AXWindow",
        subrole: "AXStandardWindow",
        display: 1,
        space: 0,
        layer: 0,
        canMove: true,
        canResize: true,
        hasFocus: false,
        hasAXReference: true,
        isNativeFullscreen: false,
        isVisible: true,
        isMinimized: false
      )
    }
    let expected = try IPCResponse.json(id: "test-id", payload: payload)
    let daemon = Daemon(path: endpoint.path) { _ in expected }
    try daemon.run()
    defer { daemon.shutdown() }
    #expect(try await exchange(path: endpoint.path) == expected)
  }

  @Test("request frames above the old 64 KiB limit reach dispatch")
  func largeRequest() async throws {
    let endpoint = try TestEndpoint()
    defer { endpoint.remove() }
    let argument = String(repeating: "x", count: 70_000)
    let daemon = Daemon(path: endpoint.path) { request in
      #expect(request.args == [argument])
      return .success(id: request.id, message: "ok")
    }
    try daemon.run()
    defer { daemon.shutdown() }
    let response = try await runBlocking {
      try Client.exchange(
        IPCRequest(id: "large-request", domain: .rule, command: "--add", args: [argument]),
        path: endpoint.path
      )
    }
    #expect(response == .success(id: "large-request", message: "ok"))
  }

  @Test("EOF uses the package's combined closed-or-timeout diagnostic")
  func closedConnection() async throws {
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
    #expect(output.1 == "error: Connection closed or timed out.")
  }

  @Test("slow readers do not block other requests or shutdown")
  func slowReader() async throws {
    let endpoint = try TestEndpoint()
    defer { endpoint.remove() }
    let large = String(repeating: "x", count: 200_000)
    let daemon = Daemon(path: endpoint.path) { request in
      .success(id: request.id, message: request.command == "large" ? large : "ok")
    }
    try daemon.run()
    defer { daemon.shutdown() }
    let fd = try LocalSocket.connect(path: endpoint.path)
    defer { close(fd) }
    try LocalSocket.send(
      Data(
        (#"{"version":1,"id":"slow","domain":"query","command":"large","args":[]}"# + "\n").utf8
      ),
      to: fd
    )
    try await runBlocking {
      var socket = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
      try #require(poll(&socket, 1, 2_000) == 1)
      #expect(socket.revents & Int16(POLLIN) != 0)
    }

    // Leave the large response unread while another client completes its request.
    #expect(try await exchange(path: endpoint.path) == .success(id: "test-id", message: "ok"))
    daemon.shutdown()
    let response = try await runBlocking { try readToEOF(fd) }
    #expect(response.count < large.utf8.count)
    #expect(!response.contains(10))
  }

  @Test("daemon does not retain itself through its server handler")
  func lifetime() throws {
    let endpoint = try TestEndpoint()
    defer { endpoint.remove() }
    weak var weakDaemon: Daemon?
    do {
      let daemon = Daemon(path: endpoint.path) { .success(id: $0.id, message: "ok") }
      weakDaemon = daemon
      try daemon.run()
    }
    #expect(weakDaemon == nil)
    #expect(!FileManager.default.fileExists(atPath: endpoint.path))
  }

  private func exchange(path: String, version: Int = 1) async throws -> IPCResponse {
    try await runBlocking {
      try Client.exchange(
        IPCRequest(version: version, id: "test-id", domain: .query, command: "windows", args: []),
        path: path
      )
    }
  }
}

private struct TestEndpoint: Sendable {
  let directory: URL
  var path: String { directory.appendingPathComponent("ipc.sock").path }

  init() throws {
    directory = URL(fileURLWithPath: "/tmp/swm-ipc-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
  }

  func remove() { try? FileManager.default.removeItem(at: directory) }
}
