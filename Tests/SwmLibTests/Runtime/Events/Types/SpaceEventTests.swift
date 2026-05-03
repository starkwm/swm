import Testing

@testable import SwmLib

@Suite("SpaceEvent")
struct SpaceEventTests {
  @Test("type: exposes space event types")
  func typeExposesSpaceEventTypes() {
    let space = Space(id: 1, type: .normal)

    #expect(SpaceEvent.changed(space).type == .spaceChanged)
  }
}
