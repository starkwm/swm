import Testing

@testable import SwmLib

@Suite("WindowDisplayTarget")
struct WindowDisplayTargetTests {
  @Test("init: accepts relative and indexed targets")
  func initAcceptsRelativeAndIndexedTargets() {
    #expect(WindowDisplayTarget(argument: "next") != nil)
    #expect(WindowDisplayTarget(argument: "prev") != nil)
    #expect(WindowDisplayTarget(argument: "previous") != nil)
    #expect(WindowDisplayTarget(argument: "1") != nil)
  }

  @Test("init: rejects invalid targets")
  func initRejectsInvalidTargets() {
    #expect(WindowDisplayTarget(argument: "primary") == nil)
    #expect(WindowDisplayTarget(argument: "secondary") == nil)
    #expect(WindowDisplayTarget(argument: "recent") == nil)
    #expect(WindowDisplayTarget(argument: "0") == nil)
    #expect(WindowDisplayTarget(argument: "-1") == nil)
    #expect(WindowDisplayTarget(argument: "x") == nil)
  }
}
