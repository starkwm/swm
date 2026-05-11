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
    let gridFocused = try IPCRequest.make(
      domain: .window,
      arguments: ["--grid", "3:1:0:0:2:1"]
    )
    let gridRecent = try IPCRequest.make(
      domain: .window,
      arguments: ["--grid", "recent", "3:1:0:0:2:1"]
    )

    #expect(recent.command == "--move")
    #expect(recent.args == ["recent", "abs:100:200"])
    #expect(windowID.command == "--resize")
    #expect(windowID.args == ["100", "abs:500:800"])
    #expect(gridFocused.command == "--grid")
    #expect(gridFocused.args == ["3:1:0:0:2:1"])
    #expect(gridRecent.command == "--grid")
    #expect(gridRecent.args == ["recent", "3:1:0:0:2:1"])
  }

  @Test("make: builds query request")
  func makeBuildsQueryRequest() throws {
    let request = try IPCRequest.make(domain: .query, arguments: ["--display"])

    #expect(request.domain == .query)
    #expect(request.command == "--displays")
    #expect(request.args == ["--display"])
  }

  @Test("make: builds signal request")
  func makeBuildsSignalRequest() throws {
    let request = try IPCRequest.make(
      domain: .signal,
      arguments: ["--add", "event=window-focused", "action=echo"]
    )

    #expect(request.domain == .signal)
    #expect(request.command == "--add")
    #expect(request.args == ["event=window-focused", "action=echo"])
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
