import Testing

@testable import SwmLib

@Suite("IPCArguments")
struct IPCArgumentsTests {
  @Test("argument shapes: return parsed values")
  func argumentShapesReturnParsedValues() throws {
    try IPCArguments([], context: "test").requireEmpty()
    #expect(try IPCArguments(["value"], context: "test").requiredValue() == "value")
    #expect(try IPCArguments([], context: "test").optionalValue() == nil)
    #expect(try IPCArguments(["selector"], context: "test").optionalValue() == "selector")

    let value = try IPCArguments(["value"], context: "test").selectedValue()
    let selectedValue = try IPCArguments(["selector", "value"], context: "test").selectedValue()
    #expect(value.selector == nil)
    #expect(value.value == "value")
    #expect(selectedValue.selector == "selector")
    #expect(selectedValue.value == "value")
  }

  @Test("argument shapes: reject invalid counts with context")
  func argumentShapesRejectInvalidCountsWithContext() {
    let expectedError = IPCCommandError.invalidRequest("invalid test context arguments")

    #expect(
      error { try IPCArguments(["extra"], context: "test context").requireEmpty() } == expectedError
    )
    #expect(
      error { _ = try IPCArguments([], context: "test context").requiredValue() } == expectedError
    )
    #expect(
      error { _ = try IPCArguments(["one", "two"], context: "test context").requiredValue() }
        == expectedError
    )
    #expect(
      error { _ = try IPCArguments(["one", "two"], context: "test context").optionalValue() }
        == expectedError
    )
    #expect(
      error { _ = try IPCArguments([], context: "test context").selectedValue() } == expectedError
    )
    #expect(
      error {
        _ = try IPCArguments(["one", "two", "three"], context: "test context").selectedValue()
      } == expectedError
    )
  }

  private func error(_ action: () throws -> Void) -> IPCCommandError? {
    do {
      try action()
      return nil
    } catch let error as IPCCommandError {
      return error
    } catch {
      return nil
    }
  }
}
