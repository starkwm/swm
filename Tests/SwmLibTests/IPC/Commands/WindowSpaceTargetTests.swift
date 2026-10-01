import Testing

@testable import SwmLib

@Suite("WindowSpaceTarget")
struct WindowSpaceTargetTests {
  @Test("init: accepts zero-based indexes and desktop cycling")
  func parsing() {
    #expect(WindowSpaceTarget(argument: "0") == .index(0))
    #expect(WindowSpaceTarget(argument: "2") == .index(2))

    #expect(WindowSpaceTarget(argument: "next") == .next)
    #expect(WindowSpaceTarget(argument: "prev") == .previous)
    #expect(WindowSpaceTarget(argument: "previous") == .previous)
  }

  @Test(
    "init: rejects invalid indexes",
    arguments: ["", "-1", "1.5", "sideways", "999999999999999999999"]
  )
  func invalidArguments(argument: String) {
    #expect(WindowSpaceTarget(argument: argument) == nil)
  }

  @Test("space: numeric indexes include fullscreen Spaces in query order")
  func indexedSpace() {
    #expect(WindowSpaceTarget.index(0).space(from: 11, spaces: spaces)?.id == 11)
    #expect(WindowSpaceTarget.index(1).space(from: 11, spaces: spaces)?.id == 22)

    #expect(WindowSpaceTarget.index(3).space(from: 11, spaces: spaces) == nil)
    #expect(WindowSpaceTarget.index(-1).space(from: 11, spaces: spaces) == nil)
  }

  @Test("space: cycling skips fullscreen Spaces and wraps")
  func cycling() {
    #expect(WindowSpaceTarget.next.space(from: 11, spaces: spaces)?.id == 33)
    #expect(WindowSpaceTarget.next.space(from: 33, spaces: spaces)?.id == 11)

    #expect(WindowSpaceTarget.previous.space(from: 11, spaces: spaces)?.id == 33)
    #expect(WindowSpaceTarget.previous.space(from: 33, spaces: spaces)?.id == 11)

    #expect(WindowSpaceTarget.next.space(from: 22, spaces: spaces) == nil)
    #expect(WindowSpaceTarget.next.space(from: 11, spaces: []) == nil)
  }

  private var spaces: [Space] {
    [Space(id: 11, type: .normal), Space(id: 22, type: .fullscreen), Space(id: 33, type: .normal)]
  }
}
