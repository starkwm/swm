import Testing

@testable import SwmLib

@Suite("IPCRequest query")
struct IPCRequestQueryTests {
  @Test("make(domain:arguments:): accepts displays query flag")
  func makeAcceptsDisplaysQueryFlag() throws {
    let request = try IPCRequest.make(domain: .query, arguments: ["--displays"])

    #expect(request.command == "--displays")
    #expect(request.args == [])
  }

  @Test("make(domain:arguments:): accepts windows query flag")
  func makeAcceptsWindowsQueryFlag() throws {
    let request = try IPCRequest.make(domain: .query, arguments: ["--windows"])

    #expect(request.command == "--windows")
    #expect(request.args == [])
  }

  @Test("make(domain:arguments:): accepts spaces query flag")
  func makeAcceptsSpacesQueryFlag() throws {
    let request = try IPCRequest.make(domain: .query, arguments: ["--spaces"])

    #expect(request.command == "--spaces")
    #expect(request.args == [])
  }

  @Test("make(domain:arguments:): rejects missing query flag")
  func makeRejectsMissingQueryFlag() {
    do {
      _ = try IPCRequest.make(domain: .query, arguments: [])
      Issue.record("Expected missing query flag to fail")
    } catch {}
  }

  @Test("make(domain:arguments:): rejects multiple query flags")
  func makeRejectsMultipleQueryFlags() {
    do {
      _ = try IPCRequest.make(domain: .query, arguments: ["--displays", "--windows"])
      Issue.record("Expected multiple query flags to fail")
    } catch {}
  }

  @Test("make(domain:arguments:): accepts selector flags without values")
  func makeAcceptsSelectorFlagsWithoutValues() throws {
    let request = try IPCRequest.make(domain: .query, arguments: ["--windows", "--display"])

    #expect(request.command == "--windows")
    #expect(request.args == ["--display"])
  }

  @Test("make(domain:arguments:): defaults singular display query to focused display")
  func makeDefaultsSingularDisplayQueryToFocusedDisplay() throws {
    let request = try IPCRequest.make(domain: .query, arguments: ["--display"])

    #expect(request.command == "--displays")
    #expect(request.args == ["--display"])
  }

  @Test("make(domain:arguments:): defaults singular space query to focused space")
  func makeDefaultsSingularSpaceQueryToFocusedSpace() throws {
    let request = try IPCRequest.make(domain: .query, arguments: ["--space"])

    #expect(request.command == "--spaces")
    #expect(request.args == ["--space"])
  }

  @Test("make(domain:arguments:): defaults singular window query to focused window")
  func makeDefaultsSingularWindowQueryToFocusedWindow() throws {
    let request = try IPCRequest.make(domain: .query, arguments: ["--window"])

    #expect(request.command == "--windows")
    #expect(request.args == ["--window"])
  }

  @Test("make(domain:arguments:): accepts selector flags with values")
  func makeAcceptsSelectorFlagsWithValues() throws {
    let request = try IPCRequest.make(domain: .query, arguments: ["--spaces", "--window", "42"])

    #expect(request.command == "--spaces")
    #expect(request.args == ["--window", "42"])
  }

  @Test("make(domain:arguments:): accepts singular query flags with values")
  func makeAcceptsSingularQueryFlagsWithValues() throws {
    let display = try IPCRequest.make(domain: .query, arguments: ["--display", "1"])
    let space = try IPCRequest.make(domain: .query, arguments: ["--space", "2"])
    let window = try IPCRequest.make(domain: .query, arguments: ["--window", "42"])

    #expect(display.command == "--displays")
    #expect(display.args == ["--display", "1"])
    #expect(space.command == "--spaces")
    #expect(space.args == ["--space", "2"])
    #expect(window.command == "--windows")
    #expect(window.args == ["--window", "42"])
  }

  @Test("make(domain:arguments:): rejects bare query command")
  func makeRejectsBareQueryCommand() {
    do {
      _ = try IPCRequest.make(domain: .query, arguments: ["displays"])
      Issue.record("Expected bare query command to fail")
    } catch let error as IPCCommandError {
      #expect(error.message == "unsupported query argument: displays")
      #expect(error.errorCode == .invalidRequest)
    } catch {}
  }

  @Test("make(domain:arguments:): rejects multiple selectors")
  func makeRejectsMultipleSelectors() {
    do {
      _ = try IPCRequest.make(domain: .query, arguments: ["--windows", "--display", "--space"])
      Issue.record("Expected multiple selectors to fail")
    } catch let error as IPCCommandError {
      #expect(error.message == "only one query selector is allowed")
      #expect(error.errorCode == .invalidRequest)
    } catch {}
  }

  @Test("make(domain:arguments:): rejects multiple selector values")
  func makeRejectsMultipleSelectorValues() {
    do {
      _ = try IPCRequest.make(domain: .query, arguments: ["--windows", "--display", "1", "2"])
      Issue.record("Expected multiple selector values to fail")
    } catch let error as IPCCommandError {
      #expect(error.message == "query selector accepts at most one value")
      #expect(error.errorCode == .invalidRequest)
    } catch {}
  }

  @Test("make(domain:arguments:): rejects invalid selector values")
  func makeRejectsInvalidSelectorValues() {
    do {
      _ = try IPCRequest.make(domain: .query, arguments: ["--windows", "--display", "0"])
      Issue.record("Expected invalid display selector value to fail")
    } catch let error as IPCCommandError {
      #expect(error.message == "query display selector value must be a positive integer")
      #expect(error.errorCode == .invalidRequest)
    } catch {}

    do {
      _ = try IPCRequest.make(domain: .query, arguments: ["--windows", "--space", "-1"])
      Issue.record("Expected invalid selector value to fail")
    } catch let error as IPCCommandError {
      #expect(error.message == "query space selector value must be a non-negative integer")
      #expect(error.errorCode == .invalidRequest)
    } catch {}

    do {
      _ = try IPCRequest.make(domain: .query, arguments: ["--windows", "--window", "abc"])
      Issue.record("Expected invalid window selector value to fail")
    } catch let error as IPCCommandError {
      #expect(error.message == "query window selector value must be a window id")
      #expect(error.errorCode == .invalidRequest)
    } catch {}
  }
}
