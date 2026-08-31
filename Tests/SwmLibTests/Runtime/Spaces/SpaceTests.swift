import Testing

@testable import SwmLib

@Suite("Space")
struct SpaceTests {
  @Test("init: stores explicit id and type")
  func initStoresExplicitIDAndType() {
    let space = Space(id: 42, type: .fullscreen)

    #expect(space.id == 42)
    #expect(space.type == .fullscreen)
  }

  @Test("description: includes id and type")
  func descriptionIncludesIDAndType() {
    let space = Space(id: 42, type: .normal)

    #expect(space.description == "<Space id: 42, type: normal>")
  }

  @Test("equality: compares spaces by id")
  func equalityComparesSpacesByID() {
    let space = Space(id: 42, type: .normal)

    #expect(space == Space(id: 42, type: .fullscreen))
    #expect(space != Space(id: 43, type: .normal))
  }
}
