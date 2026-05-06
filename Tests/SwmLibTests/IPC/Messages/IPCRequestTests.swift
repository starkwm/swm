import Testing

@testable import SwmLib

@Suite("IPCRequest")
struct IPCRequestTests {
  @Test("make: splits command from arguments")
  func makeSplitsCommandFromArguments() throws {
    let request = try IPCRequest.make(domain: .window, arguments: ["focus", "main display"])

    #expect(request.version == IPCRequest.currentVersion)
    #expect(request.domain == .window)
    #expect(request.command == "focus")
    #expect(request.args == ["main display"])
  }

  @Test("make: parses command-first window selector arguments")
  func makeParsesCommandFirstWindowSelectorArguments() throws {
    let recent = try IPCRequest.make(
      domain: .window,
      arguments: ["--move", "recent", "abs:100:200"]
    )
    let windowID = try IPCRequest.make(
      domain: .window,
      arguments: ["--resize", "100", "abs:500:800"]
    )

    #expect(recent.command == "--move")
    #expect(recent.args == ["recent", "abs:100:200"])
    #expect(windowID.command == "--resize")
    #expect(windowID.args == ["100", "abs:500:800"])
  }

  @Test("make: builds query request")
  func makeBuildsQueryRequest() throws {
    let request = try IPCRequest.make(domain: .query, arguments: ["--display"])

    #expect(request.domain == .query)
    #expect(request.command == "--displays")
    #expect(request.args == ["--display"])
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
}
