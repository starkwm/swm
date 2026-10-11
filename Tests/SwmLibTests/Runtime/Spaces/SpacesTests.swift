import Testing

@testable import SwmLib

@Suite("Spaces")
@MainActor
struct SpacesTests {
  @Test(
    "activeSpaceDidChange: keeps the previous distinct Space across repeated events",
    arguments: [nil, 1] as [UInt64?]
  )
  func activeSpaceDidChangeKeepsThePreviousDistinctSpaceAcrossRepeatedEvents(initialID: UInt64?) {
    let spaces = Spaces(activeSpaceID: initialID)

    spaces.activeSpaceDidChange(to: 2)

    #expect(spaces.currentActiveSpaceID == 2)
    #expect(spaces.lastActiveSpaceID == initialID)

    spaces.activeSpaceDidChange(to: 2)
    #expect(spaces.lastActiveSpaceID == initialID)

    spaces.activeSpaceDidChange(to: 3)
    spaces.activeSpaceDidChange(to: 3)
    #expect(spaces.currentActiveSpaceID == 3)
    #expect(spaces.lastActiveSpaceID == 2)
  }
}
