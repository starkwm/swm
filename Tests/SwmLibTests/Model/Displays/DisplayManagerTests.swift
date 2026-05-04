import Testing

@testable import SwmLib

@Suite("DisplayManager")
struct DisplayManagerTests {
  @Test("init: seeds current active display")
  func initSeedsCurrentActiveDisplay() {
    let manager = DisplayManager(activeDisplayIDResolver: { "display-1" })

    #expect(manager.currentActiveDisplayID == "display-1")
    #expect(manager.lastActiveDisplayID == nil)
  }

  @Test("activeDisplayDidChange: updates current and last display")
  func activeDisplayDidChangeUpdatesCurrentAndLastDisplay() {
    let resolver = ActiveDisplayIDSequence(["display-1", "display-2"])
    let manager = DisplayManager(activeDisplayIDResolver: resolver.next)

    manager.activeDisplayDidChange()

    #expect(manager.currentActiveDisplayID == "display-2")
    #expect(manager.lastActiveDisplayID == "display-1")
  }

  @Test("activeDisplayDidChange: keeps last display for repeated active display")
  func activeDisplayDidChangeKeepsLastDisplayForRepeatedActiveDisplay() {
    let resolver = ActiveDisplayIDSequence(["display-1", "display-2", "display-2"])
    let manager = DisplayManager(activeDisplayIDResolver: resolver.next)

    manager.activeDisplayDidChange()
    manager.activeDisplayDidChange()

    #expect(manager.currentActiveDisplayID == "display-2")
    #expect(manager.lastActiveDisplayID == "display-1")
  }

  @Test("activeDisplayDidChange: ignores nil active display")
  func activeDisplayDidChangeIgnoresNilActiveDisplay() {
    let resolver = ActiveDisplayIDSequence(["display-1", nil])
    let manager = DisplayManager(activeDisplayIDResolver: resolver.next)

    manager.activeDisplayDidChange()

    #expect(manager.currentActiveDisplayID == "display-1")
    #expect(manager.lastActiveDisplayID == nil)
  }
}

private final class ActiveDisplayIDSequence: @unchecked Sendable {
  private var values: [String?]

  init(_ values: [String?]) {
    self.values = values
  }

  func next() -> String? {
    guard !values.isEmpty else { return nil }

    return values.removeFirst()
  }
}
