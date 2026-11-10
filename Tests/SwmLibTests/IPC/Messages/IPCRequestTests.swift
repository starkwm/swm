import Foundation
import Testing

@testable import SwmLib

@Suite("IPCRequest")
struct IPCRequestTests {
  @Test("make: preserves literal command arguments")
  func makePreservesLiteralCommandArguments() throws {
    let arguments = ["--focus", "main display", "--title=A window with spaces", "a=b"]
    let request = try IPCRequest.make(domain: .window, arguments: arguments)
    #expect(request.version == IPCRequest.currentVersion)
    #expect(request.domain == .window)
    #expect(request.command == "--focus")
    #expect(request.args == Array(arguments.dropFirst()))
  }

  @Test("make: requires command")
  func makeRequiresCommand() {
    do {
      _ = try IPCRequest.make(domain: .config, arguments: [])
      Issue.record("Expected missing command error")
    } catch let error as IPCCommandError {
      #expect(error.description == "missing command for config")
      #expect(error.errorCode == .invalidRequest)
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  @Test("encode/decode: preserves the legacy request schema")
  func encodeDecodePreservesTheLegacyRequestSchema() throws {
    let fixture =
      #"{"args":["main display","--title=A window with spaces"],"command":"focus","domain":"window","id":"request-id","version":1}"#
    let request = IPCRequest(
      id: "request-id",
      domain: .window,
      command: "focus",
      args: ["main display", "--title=A window with spaces"]
    )
    #expect(try wireJSON(request) == fixture)
    #expect(try JSONDecoder().decode(IPCRequest.self, from: Data(fixture.utf8)) == request)
  }

  private func wireJSON(_ value: some Encodable) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return String(decoding: try encoder.encode(value), as: UTF8.self)
  }
}
