import Testing

@testable import SwmLib

@Suite("SpaceType")
struct SpaceTypeTests {
  @Test("description: describes known space types")
  func descriptionDescribesKnownSpaceTypes() {
    #expect(SpaceType.normal.description == "normal")
    #expect(SpaceType.fullscreen.description == "fullscreen")
    #expect(SpaceType.unknown.description == "unknown")
  }
}
