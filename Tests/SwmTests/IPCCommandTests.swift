import ArgumentParser
import Darwin
import Foundation
import Testing

@testable import Swm
@testable import SwmLib

@Suite("IPC command output")
struct IPCCommandTests {
  @Test("routes responses and preserves failure exit status", arguments: [true, false])
  func outputRouting(ok: Bool) throws {
    let output = try #require(tmpfile())
    defer { fclose(output) }
    let errors = try #require(tmpfile())
    defer { fclose(errors) }
    var command = try #require(
      Arguments.parseAsRoot(["window", "focus", "--window", "42"]) as? WindowCommand.Focus
    )
    let message = ok ? "ok" : "error: window not found"
    let send: (CommandDomain, [String]) -> Client.SendResult = { domain, args in
      #expect(domain == .window)
      #expect(args == ["--focus", "42"])
      return Client.SendResult(ok: ok, outputMessage: message)
    }
    if ok {
      try command.run(send: send, output: output, errors: errors)
    } else {
      #expect(throws: ExitCode.failure) {
        try command.run(send: send, output: output, errors: errors)
      }
    }
    #expect(read(output) == (ok ? message + "\n" : ""))
    #expect(read(errors) == (ok ? "" : message + "\n"))
  }

  private func read(_ stream: UnsafeMutablePointer<FILE>) -> String {
    fflush(stream)
    rewind(stream)
    let data = FileHandle(fileDescriptor: fileno(stream), closeOnDealloc: false)
      .readDataToEndOfFile()
    return String(decoding: data, as: UTF8.self)
  }
}
