import Testing

@testable import SwmLib

@Suite("WindowTarget")
struct WindowTargetTests {
  @Test("init: accepts selectors and cardinal directions")
  func initAcceptsSelectorsAndCardinalDirections() {
    #expect(WindowTarget(arguments: []) == .selected(nil))
    #expect(WindowTarget(arguments: ["recent"]) == .selected("recent"))
    #expect(WindowTarget(arguments: ["42"]) == .selected("42"))
    #expect(WindowTarget(arguments: ["left"]) == .direction(.left))
    #expect(WindowTarget(arguments: ["right"]) == .direction(.right))
    #expect(WindowTarget(arguments: ["up"]) == .direction(.up))
    #expect(WindowTarget(arguments: ["down"]) == .direction(.down))
  }

  @Test("init: rejects multiple arguments")
  func initRejectsMultipleArguments() {
    #expect(WindowTarget(arguments: ["42", "left"]) == nil)
  }
}
