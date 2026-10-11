import Darwin
import Foundation
import StarkIPC
import Testing

@testable import SwmLib

@Suite("Daemon")
@MainActor
struct DaemonTests {
  @Test("run: dispatches socket requests on the main actor with failure IDs")
  func runDispatchesSocketRequestsOnTheMainActorWithFailureIDs() async throws {
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

  @Test("run: updates application settings through client transport and dispatch")
  func runUpdatesApplicationSettingsThroughClientTransportAndDispatch() async throws {
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
    let result = try await runBlocking {
      let response = Client.send(domain: .config, args: ["window-gap", "17"]) {
        try Client.exchange($0, path: endpoint.path)
      }
      return (response.ok, response.outputMessage)
    }
    #expect(result.0)
    #expect(result.1 == "ok")
    #expect(spaces.settings(for: 42).gap == 17)
  }

  @Test("run: rejects unsupported versions before dispatch and preserves IDs")
  func runRejectsUnsupportedVersionsBeforeDispatchAndPreservesIDs() async throws {
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

  @Test("run: rejects malformed legacy input with an empty ID")
  func runRejectsMalformedLegacyInputWithAnEmptyID() async throws {
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

  @Test("run: accepts a legacy newline client request")
  func runAcceptsALegacyNewlineClientRequest() async throws {
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

  @Test("run: rejects unterminated legacy input before dispatch")
  func runRejectsUnterminatedLegacyInputBeforeDispatch() async throws {
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

  @Test(
    "run: preserves sorted query JSON and full width identifiers",
    arguments: [false, true]
  )
  func runPreservesSortedQueryJSONAndFullWidthIdentifiers(emptyWindows: Bool) async throws {
    let endpoint = try TestEndpoint()
    defer { endpoint.remove() }
    let daemon = Daemon(path: endpoint.path) { request in
      try! .json(
        id: request.id,
        payload: SpaceSerializer(
          id: UInt64.max,
          index: 0,
          type: "user",
          displays: [1, 2],
          windows: emptyWindows ? [] : [42],
          hasFocus: true,
          isVisible: true,
          isNativeFullscreen: false
        )
      )
    }
    try daemon.run()
    defer { daemon.shutdown() }
    let response = try await exchange(path: endpoint.path)
    let windowsJSON = emptyWindows ? "[]" : "[42]"
    #expect(
      response.message
        == #"{"displays":[1,2],"has-focus":true,"id":18446744073709551615,"index":0,"is-native-fullscreen":false,"is-visible":true,"type":"user","windows":\#(windowsJSON)}"#
    )
  }

  @Test("run: delivers realistic window query payloads", arguments: [1, 32, 256])
  func runDeliversRealisticWindowQueryPayloads(windowCount: Int) async throws {
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

  @Test("run: dispatches requests above the legacy frame limit")
  func runDispatchesRequestsAboveTheLegacyFrameLimit() async throws {
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

  @Test("run: releases the daemon and removes its endpoint")
  func runReleasesTheDaemonAndRemovesItsEndpoint() throws {
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

  @Test("shutdown: rejects queued work across restart")
  func shutdownRejectsQueuedWorkAcrossRestart() async throws {
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

  @Test("shutdown: closes slow readers without blocking other requests")
  func shutdownClosesSlowReadersWithoutBlockingOtherRequests() async throws {
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

  @Test(
    "shutdown: cancels suspended commands and permits restart",
    .timeLimit(.minutes(1))
  )
  func shutdownCancelsSuspendedCommandsAndPermitsRestart() async throws {
    let endpoint = try TestEndpoint()
    defer { endpoint.remove() }

    let (started, startContinuation) = AsyncStream<Void>.makeStream()
    let (cancelled, cancellationContinuation) = AsyncStream<Void>.makeStream()

    let daemon = Daemon(path: endpoint.path) { request in
      if request.command == "slow" {
        defer { cancellationContinuation.finish() }

        startContinuation.yield(())
        startContinuation.finish()

        do {
          try await Task.sleep(for: .seconds(30))

          Issue.record("suspended request was not cancelled")
        } catch {
          #expect(error is CancellationError)

          cancellationContinuation.yield(())
        }
      }

      return .success(id: request.id, message: "ok")
    }

    try daemon.run()
    defer { daemon.shutdown() }

    let fd = try LocalSocket.connect(path: endpoint.path)
    defer { close(fd) }

    try LocalSocket.send(
      Data((#"{"version":1,"id":"slow","domain":"query","command":"slow","args":[]}"# + "\n").utf8),
      to: fd
    )

    var starts = started.makeAsyncIterator()
    _ = await starts.next()

    #expect(try await exchange(path: endpoint.path) == .success(id: "test-id", message: "ok"))

    daemon.shutdown()

    var cancellations = cancelled.makeAsyncIterator()
    let signal = await cancellations.next()

    try #require(signal != nil)

    // A fresh run must still accept commands after the cancelled request has unwound.
    try daemon.run()

    #expect(try await exchange(path: endpoint.path) == .success(id: "test-id", message: "ok"))
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
