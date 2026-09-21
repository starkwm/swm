import StarkSkyLight
import Testing

@testable import SwmLib

@Suite("SpaceType")
struct SpaceTypeTests {
  @Test(
    "package types preserve existing query strings",
    arguments: [
      (StarkSkyLight.SpaceType.desktop, "normal"),
      (.fullscreen, "fullscreen"),
      (.unknown(1), "unknown"),
      (.unknown(99), "unknown"),
    ]
  )
  func packageTypes(type: StarkSkyLight.SpaceType, expected: String) {
    #expect(SwmLib.SpaceType(type).description == expected)
  }

  @Test("description: describes known space types")
  func descriptionDescribesKnownSpaceTypes() {
    #expect(SpaceType.normal.description == "normal")
    #expect(SpaceType.fullscreen.description == "fullscreen")
    #expect(SpaceType.unknown.description == "unknown")
  }
}
