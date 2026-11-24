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
    let send: (IPCCommand) -> Client.SendResult = { ipcCommand in
      Client.send(ipcCommand) { request in
        #expect(request.command == .window(.focus(.selected(.id(42)))))
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
      (["display"], IPCCommand.query(.displays, .display(nil))),
      (["display", "2"], .query(.displays, .display(2))),
      (["space", "3"], .query(.spaces, .space(3))),
      (["window"], .query(.windows, .window(nil))),
      (["window", "42"], .query(.windows, .window(42))),
      (["windows", "--space", "3"], .query(.windows, .space(3))),
    ]
  )
  func querySingularCommandsSendThePluralCommandWithASelector(
    arguments: [String],
    expected: IPCCommand
  ) throws {
    let command = try #require(Arguments.parseAsRoot(["query"] + arguments) as? any DaemonCommand)
    #expect(command.ipcCommand == expected)
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
        .command(.reload(.begin(processID: 42))),
        .exec("/tmp/swmrc", "token"),
        .command(.reload(.commit(token: "token"))),
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
        .command(.reload(.begin(processID: 42))),
        .exec("/tmp/swmrc", "token"),
        .command(.reload(.rollback(token: "token"))),
      ]
    )
    #expect(
      read(errors)
        == "Error: configuration file exited with status 1\n"
        + "Kept the previous rules and settings.\n"
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
    #expect(reload.calls == [.command(.reload(.begin(processID: 42)))])
    #expect(read(errors) == "Error: a configuration reload is already in progress\n")
  }

  @Test("reload: clears rules, then runs the file, for a daemon without reloads")
  func reloadClearsRulesThenRunsTheFileForADaemonWithoutReloads() throws {
    let errors = try #require(tmpfile())
    defer { fclose(errors) }
    let command = try #require(
      Arguments.parseAsRoot(["reload", "--config", "/tmp/swmrc"]) as? ReloadCommand
    )
    let reload = RecordedReload(
      begin: Client.SendResult(
        ok: false,
        outputMessage: "Error: unsupported reload command",
        errorCode: .unsupportedCommand
      )
    )

    try command.run(send: reload.send, execute: reload.execute, processID: 42, errors: errors)

    #expect(
      reload.calls == [
        .command(.reload(.begin(processID: 42))),
        .command(.rule(.clear)),
        .exec("/tmp/swmrc", nil),
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
  enum Call: Equatable {
    case command(IPCCommand)
    case exec(String, String?)
  }

  private(set) var calls = [Call]()
  private let begin: Client.SendResult
  private let executeFails: Bool

  init(
    begin: Client.SendResult = Client.SendResult(ok: true, outputMessage: "token"),
    executeFails: Bool = false
  ) {
    self.begin = begin
    self.executeFails = executeFails
  }

  func send(_ command: IPCCommand) -> Client.SendResult {
    calls.append(.command(command))
    if case .reload(.begin) = command { return begin }
    return Client.SendResult(ok: true, outputMessage: "")
  }

  func execute(_ path: String, _ token: String?) throws {
    calls.append(.exec(path, token))
    if executeFails { throw ConfigError.configurationFailed(status: 1) }
  }
}
