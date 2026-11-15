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

  @Test(
    "query: singular commands send the plural command with a selector",
    arguments: [
      (["display"], ["--displays", "--display"]),
      (["display", "2"], ["--displays", "--display", "2"]),
      (["space", "3"], ["--spaces", "--space", "3"]),
      (["window"], ["--windows", "--window"]),
      (["window", "42"], ["--windows", "--window", "42"]),
      (["windows", "--space", "3"], ["--windows", "--space", "3"]),
    ]
  )
  func querySingularCommandsSendThePluralCommandWithASelector(
    arguments: [String],
    expected: [String]
  ) throws {
    let command = try #require(Arguments.parseAsRoot(["query"] + arguments) as? any IPCCommand)
    #expect(command.commandArguments == expected)
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

  @Test("reload: runs the file in a daemon reload and commits it when the file succeeds")
  func reloadRunsTheFileInADaemonReloadAndCommitsItWhenTheFileSucceeds() throws {
    let errors = try #require(tmpfile())
    defer { fclose(errors) }
    let command = try #require(
      Arguments.parseAsRoot(["reload", "--config", "/tmp/swmrc"]) as? ReloadCommand
    )
    let reload = RecordedReload()

    try command.run(send: reload.send, execute: reload.execute, processID: 42, errors: errors)

    #expect(
      reload.calls == [
        "config --begin-reload 42", "exec /tmp/swmrc token", "config --commit-reload token",
      ]
    )
    #expect(read(errors).isEmpty)
  }

  @Test("reload: rolls back when the file fails")
  func reloadRollsBackWhenTheFileFails() throws {
    let errors = try #require(tmpfile())
    defer { fclose(errors) }
    let command = try #require(
      Arguments.parseAsRoot(["reload", "--config", "/tmp/swmrc"]) as? ReloadCommand
    )
    let reload = RecordedReload(executeFails: true)

    #expect(throws: ExitCode.failure) {
      try command.run(send: reload.send, execute: reload.execute, processID: 42, errors: errors)
    }
    #expect(
      reload.calls == [
        "config --begin-reload 42", "exec /tmp/swmrc token", "config --rollback-reload token",
      ]
    )
    #expect(
      read(errors)
        == "Error: configuration file exited with status 1\n"
        + "Kept the previous rules, signals, and settings.\n"
    )
  }

  @Test("reload: stops before running the file when the daemon cannot begin a reload")
  func reloadStopsBeforeRunningTheFileWhenTheDaemonCannotBeginAReload() throws {
    let errors = try #require(tmpfile())
    defer { fclose(errors) }
    let command = try #require(Arguments.parseAsRoot(["reload"]) as? ReloadCommand)
    let reload = RecordedReload(
      begin: Client.SendResult(
        ok: false,
        outputMessage: "Error: a configuration reload is already in progress",
        errorCode: .invalidRequest
      )
    )

    #expect(throws: ExitCode.failure) {
      try command.run(send: reload.send, execute: reload.execute, processID: 42, errors: errors)
    }
    #expect(reload.calls == ["config --begin-reload 42"])
    #expect(read(errors) == "Error: a configuration reload is already in progress\n")
  }

  @Test("reload: clears rules and signals, then runs the file, for a daemon without reloads")
  func reloadClearsRulesAndSignalsThenRunsTheFileForADaemonWithoutReloads() throws {
    let errors = try #require(tmpfile())
    defer { fclose(errors) }
    let command = try #require(
      Arguments.parseAsRoot(["reload", "--config", "/tmp/swmrc"]) as? ReloadCommand
    )
    let reload = RecordedReload(
      begin: Client.SendResult(
        ok: false,
        outputMessage: "Error: unsupported config command: --begin-reload",
        errorCode: .unsupportedCommand
      )
    )

    try command.run(send: reload.send, execute: reload.execute, processID: 42, errors: errors)

    #expect(
      reload.calls == [
        "config --begin-reload 42", "rule --clear", "signal --clear", "exec /tmp/swmrc none",
      ]
    )
    #expect(read(errors) == "Warning: restart the daemon to make reloads all-or-nothing.\n")
  }

  private func read(_ stream: UnsafeMutablePointer<FILE>) -> String {
    fflush(stream)
    rewind(stream)
    let data = FileHandle(fileDescriptor: fileno(stream), closeOnDealloc: false)
      .readDataToEndOfFile()
    return String(decoding: data, as: UTF8.self)
  }
}

private final class RecordedReload {
  private(set) var calls = [String]()
  private let begin: Client.SendResult
  private let executeFails: Bool

  init(
    begin: Client.SendResult = Client.SendResult(ok: true, outputMessage: "token"),
    executeFails: Bool = false
  ) {
    self.begin = begin
    self.executeFails = executeFails
  }

  func send(_ domain: CommandDomain, _ args: [String]) -> Client.SendResult {
    calls.append("\(domain.rawValue) \(args.joined(separator: " "))")
    return args.first == "--begin-reload" ? begin : Client.SendResult(ok: true, outputMessage: "")
  }

  func execute(_ path: String, _ token: String?) throws {
    calls.append("exec \(path) \(token ?? "none")")
    if executeFails { throw ConfigError.configurationFailed(status: 1) }
  }
}
