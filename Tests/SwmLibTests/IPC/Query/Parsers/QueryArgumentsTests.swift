import ArgumentParser
import Testing

@testable import SwmLib

@Suite("QueryArguments")
struct QueryArgumentsTests {
  @Test("parse: accepts displays flag")
  func parseAcceptsDisplaysFlag() throws {
    let arguments = try QueryArguments.parse(["--displays"])

    #expect(try arguments.selectedCommand() == "--displays")
  }

  @Test("parse: accepts windows flag")
  func parseAcceptsWindowsFlag() throws {
    let arguments = try QueryArguments.parse(["--windows"])

    #expect(try arguments.selectedCommand() == "--windows")
  }

  @Test("parse: accepts spaces flag")
  func parseAcceptsSpacesFlag() throws {
    let arguments = try QueryArguments.parse(["--spaces"])

    #expect(try arguments.selectedCommand() == "--spaces")
  }

  @Test("selectedCommand: rejects missing query flag")
  func selectedCommandRejectsMissingQueryFlag() {
    do {
      _ = try QueryArguments.parse([]).selectedCommand()
      Issue.record("Expected missing query flag to fail")
    } catch {}
  }

  @Test("selectedCommand: rejects multiple query flags")
  func selectedCommandRejectsMultipleQueryFlags() {
    do {
      _ = try QueryArguments.parse(["--displays", "--windows"]).selectedCommand()
      Issue.record("Expected multiple query flags to fail")
    } catch {}
  }

  @Test("makeRequest: accepts selector flags without values")
  func makeRequestAcceptsSelectorFlagsWithoutValues() throws {
    let request = try QueryArguments.makeRequest(arguments: ["--windows", "--display"])

    #expect(request.command == "--windows")
    #expect(request.args == ["--display"])
  }

  @Test("makeRequest: defaults singular display query to focused display")
  func makeRequestDefaultsSingularDisplayQueryToFocusedDisplay() throws {
    let request = try QueryArguments.makeRequest(arguments: ["--display"])

    #expect(request.command == "--displays")
    #expect(request.args == ["--display"])
  }

  @Test("makeRequest: defaults singular space query to focused space")
  func makeRequestDefaultsSingularSpaceQueryToFocusedSpace() throws {
    let request = try QueryArguments.makeRequest(arguments: ["--space"])

    #expect(request.command == "--spaces")
    #expect(request.args == ["--space"])
  }

  @Test("makeRequest: defaults singular window query to focused window")
  func makeRequestDefaultsSingularWindowQueryToFocusedWindow() throws {
    let request = try QueryArguments.makeRequest(arguments: ["--window"])

    #expect(request.command == "--windows")
    #expect(request.args == ["--window"])
  }

  @Test("makeRequest: accepts selector flags with values")
  func makeRequestAcceptsSelectorFlagsWithValues() throws {
    let request = try QueryArguments.makeRequest(arguments: ["--spaces", "--window", "42"])

    #expect(request.command == "--spaces")
    #expect(request.args == ["--window", "42"])
  }

  @Test("makeRequest: accepts singular query flags with values")
  func makeRequestAcceptsSingularQueryFlagsWithValues() throws {
    let display = try QueryArguments.makeRequest(arguments: ["--display", "1"])
    let space = try QueryArguments.makeRequest(arguments: ["--space", "2"])
    let window = try QueryArguments.makeRequest(arguments: ["--window", "42"])

    #expect(display.command == "--displays")
    #expect(display.args == ["--display", "1"])
    #expect(space.command == "--spaces")
    #expect(space.args == ["--space", "2"])
    #expect(window.command == "--windows")
    #expect(window.args == ["--window", "42"])
  }

  @Test("makeRequest: rejects bare query command")
  func makeRequestRejectsBareQueryCommand() {
    do {
      _ = try QueryArguments.makeRequest(arguments: ["displays"])
      Issue.record("Expected bare query command to fail")
    } catch let error as ValidationError {
      #expect(error.message == "unsupported query argument: displays")
    } catch {}
  }

  @Test("makeRequest: rejects multiple selectors")
  func makeRequestRejectsMultipleSelectors() {
    do {
      _ = try QueryArguments.makeRequest(arguments: ["--windows", "--display", "--space"])
      Issue.record("Expected multiple selectors to fail")
    } catch let error as ValidationError {
      #expect(error.message == "only one query selector is allowed")
    } catch {}
  }

  @Test("makeRequest: rejects multiple selector values")
  func makeRequestRejectsMultipleSelectorValues() {
    do {
      _ = try QueryArguments.makeRequest(arguments: ["--windows", "--display", "1", "2"])
      Issue.record("Expected multiple selector values to fail")
    } catch let error as ValidationError {
      #expect(error.message == "query selector accepts at most one value")
    } catch {}
  }

  @Test("makeRequest: rejects invalid selector values")
  func makeRequestRejectsInvalidSelectorValues() {
    do {
      _ = try QueryArguments.makeRequest(arguments: ["--windows", "--space", "-1"])
      Issue.record("Expected invalid selector value to fail")
    } catch let error as ValidationError {
      #expect(error.message == "query selector value must be a non-negative integer")
    } catch {}

    do {
      _ = try QueryArguments.makeRequest(arguments: ["--windows", "--window", "abc"])
      Issue.record("Expected invalid window selector value to fail")
    } catch let error as ValidationError {
      #expect(error.message == "query window selector value must be a window id")
    } catch {}
  }
}
