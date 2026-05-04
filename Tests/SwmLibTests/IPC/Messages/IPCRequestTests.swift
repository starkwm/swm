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
    } catch let error as IPCRequestError {
      #expect(error.description == "missing command for config")
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }
}
