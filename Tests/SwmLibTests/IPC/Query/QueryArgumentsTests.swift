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
      #expect(
        error.message
          == "unsupported query argument: displays; use --displays, --windows, or --spaces"
      )
    } catch {}
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
}
