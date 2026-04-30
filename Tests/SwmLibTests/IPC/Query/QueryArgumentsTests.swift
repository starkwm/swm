import ArgumentParser
import Testing

@testable import SwmLib

@Suite("QueryArguments")
struct QueryArgumentsTests {
  @Test("accepts displays flag")
  func acceptsDisplaysFlag() throws {
    let arguments = try QueryArguments.parse(["--displays"])

    #expect(try arguments.selectedCommand() == "--displays")
  }

  @Test("accepts windows flag")
  func acceptsWindowsFlag() throws {
    let arguments = try QueryArguments.parse(["--windows"])

    #expect(try arguments.selectedCommand() == "--windows")
  }

  @Test("accepts spaces flag")
  func acceptsSpacesFlag() throws {
    let arguments = try QueryArguments.parse(["--spaces"])

    #expect(try arguments.selectedCommand() == "--spaces")
  }

  @Test("rejects bare query command")
  func rejectsBareQueryCommand() {
    do {
      _ = try QueryArguments.makeRequest(arguments: ["displays"])
      Issue.record("Expected bare query command to fail")
    } catch let error as ValidationError {
      #expect(error.message == "unsupported query argument: displays")
    } catch {}
  }

  @Test("accepts selector flags without values")
  func acceptsSelectorFlagsWithoutValues() throws {
    let request = try QueryArguments.makeRequest(arguments: ["--windows", "--display"])

    #expect(request.command == "--windows")
    #expect(request.args == ["--display"])
  }

  @Test("accepts selector flags with values")
  func acceptsSelectorFlagsWithValues() throws {
    let request = try QueryArguments.makeRequest(arguments: ["--spaces", "--window", "42"])

    #expect(request.command == "--spaces")
    #expect(request.args == ["--window", "42"])
  }

  @Test("rejects missing query flag")
  func rejectsMissingQueryFlag() {
    do {
      _ = try QueryArguments.parse([]).selectedCommand()
      Issue.record("Expected missing query flag to fail")
    } catch {}
  }

  @Test("rejects multiple query flags")
  func rejectsMultipleQueryFlags() {
    do {
      _ = try QueryArguments.parse(["--displays", "--windows"]).selectedCommand()
      Issue.record("Expected multiple query flags to fail")
    } catch {}
  }

  @Test("rejects multiple selectors")
  func rejectsMultipleSelectors() {
    do {
      _ = try QueryArguments.makeRequest(arguments: ["--windows", "--display", "--space"])
      Issue.record("Expected multiple selectors to fail")
    } catch let error as ValidationError {
      #expect(error.message == "only one query selector is allowed")
    } catch {}
  }

  @Test("rejects multiple selector values")
  func rejectsMultipleSelectorValues() {
    do {
      _ = try QueryArguments.makeRequest(arguments: ["--windows", "--display", "1", "2"])
      Issue.record("Expected multiple selector values to fail")
    } catch let error as ValidationError {
      #expect(error.message == "query selector accepts at most one value")
    } catch {}
  }

  @Test("rejects invalid selector values")
  func rejectsInvalidSelectorValues() {
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
