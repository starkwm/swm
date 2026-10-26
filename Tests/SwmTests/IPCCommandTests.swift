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
      (false, "error: window not found", "error: window not found"),
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

  private func read(_ stream: UnsafeMutablePointer<FILE>) -> String {
    fflush(stream)
    rewind(stream)
    let data = FileHandle(fileDescriptor: fileno(stream), closeOnDealloc: false)
      .readDataToEndOfFile()
    return String(decoding: data, as: UTF8.self)
  }
}
