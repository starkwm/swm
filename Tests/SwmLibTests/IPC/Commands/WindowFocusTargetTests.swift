import Testing

@testable import SwmLib

@Suite("WindowFocusTarget")
struct WindowFocusTargetTests {
  @Test("init: accepts selectors and cardinal directions")
  func initAcceptsSelectorsAndCardinalDirections() {
    #expect(WindowFocusTarget(arguments: []) == .selected(nil))
    #expect(WindowFocusTarget(arguments: ["recent"]) == .selected("recent"))
    #expect(WindowFocusTarget(arguments: ["42"]) == .selected("42"))
    #expect(WindowFocusTarget(arguments: ["left"]) == .direction(.left))
    #expect(WindowFocusTarget(arguments: ["right"]) == .direction(.right))
    #expect(WindowFocusTarget(arguments: ["up"]) == .direction(.up))
    #expect(WindowFocusTarget(arguments: ["down"]) == .direction(.down))
  }

  @Test("init: rejects multiple arguments")
  func initRejectsMultipleArguments() {
    #expect(WindowFocusTarget(arguments: ["42", "left"]) == nil)
  }
}
