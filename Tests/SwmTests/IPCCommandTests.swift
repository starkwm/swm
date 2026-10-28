import ArgumentParser
import Darwin
import Foundation
import Testing

@testable import Swm
@testable import SwmLib

@Suite("IPCCommand")
struct IPCCommandTests {
  @Test(
    "run: formats daemon responses, routes output, and preserves failure exit status",
    arguments: [
      (true, #"{"id":1}"#, #"{"id":1}"#),
      (true, "", ""),
      (false, "window not found", "Error: window not found"),
    ]
  )
  func runFormatsDaemonResponsesRoutesOutputAndPreservesFailureExitStatus(
    ok: Bool,
    message: String,
    expected: String
  ) throws {
    let output = try #require(tmpfile())
    defer { fclose(output) }
    let errors = try #require(tmpfile())
    defer { fclose(errors) }
    var command = try #require(
      Arguments.parseAsRoot(["window", "focus", "42"]) as? WindowCommand.Focus
    )
    let send: (CommandDomain, [String]) -> Client.SendResult = { domain, args in
      Client.send(domain: domain, args: args) { request in
        #expect(request.domain == .window)
        #expect(request.command == "--focus")
        #expect(request.args == ["42"])
        return ok
          ? .success(id: request.id, message: message)
          : .failure(id: request.id, message: message, errorCode: .invalidRequest)
      }
    }
    if ok {
      try command.run(send: send, output: output, errors: errors)
    } else {
      #expect(throws: ExitCode.failure) {
        try command.run(send: send, output: output, errors: errors)
      }
    }
    let printed = expected.isEmpty ? "" : expected + "\n"
    #expect(read(output) == (ok ? printed : ""))
    #expect(read(errors) == (ok ? "" : printed))
  }

  @Test("formatted: indents query JSON for terminals and keeps it compact for pipes")
  func formattedIndentsQueryJSONForTerminalsAndKeepsItCompactForPipes() throws {
    let command = try #require(
      Arguments.parseAsRoot(["query", "display"]) as? QueryCommand.Display
    )
    let json = #"{"index":1,"spaces":[1,2]}"#

    #expect(command.formatted(json, forTerminal: false) == json)
    #expect(
      command.formatted(json, forTerminal: true) == """
        {
          "index" : 1,
          "spaces" : [
            1,
            2
          ]
        }
        """
    )
    #expect(command.formatted("null", forTerminal: true) == "null")
  }

  @Test("reload: clears rules and signals before running the configuration file")
  func reloadClearsRulesAndSignalsBeforeRunningTheConfigurationFile() throws {
    let errors = try #require(tmpfile())
    defer { fclose(errors) }
    let command = try #require(
      Arguments.parseAsRoot(["reload", "--config", "/tmp/swmrc"]) as? ReloadCommand
    )
    var calls = [String]()

    try command.run(
      send: { domain, args in
        calls.append("\(domain.rawValue) \(args.joined(separator: " "))")
        return Client.SendResult(ok: true, outputMessage: "")
      },
      execute: { calls.append("exec \($0)") },
      errors: errors
    )

    #expect(calls == ["rule --clear", "signal --clear", "exec /tmp/swmrc"])
  }

  @Test("reload: stops before running the configuration file when clearing fails")
  func reloadStopsBeforeRunningTheConfigurationFileWhenClearingFails() throws {
    let errors = try #require(tmpfile())
    defer { fclose(errors) }
    let command = try #require(Arguments.parseAsRoot(["reload"]) as? ReloadCommand)

    #expect(throws: ExitCode.failure) {
      try command.run(
        send: { _, _ in Client.SendResult(ok: false, outputMessage: "Error: daemon is not running")
        },
        execute: { _ in Issue.record("unexpected execution") },
        errors: errors
      )
    }
    #expect(read(errors) == "Error: daemon is not running\n")
  }

  private func read(_ stream: UnsafeMutablePointer<FILE>) -> String {
    fflush(stream)
    rewind(stream)
    let data = FileHandle(fileDescriptor: fileno(stream), closeOnDealloc: false)
      .readDataToEndOfFile()
    return String(decoding: data, as: UTF8.self)
  }
}
