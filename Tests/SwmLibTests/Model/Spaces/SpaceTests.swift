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

  @Test("isEqual: compares spaces by id")
  func isEqualComparesSpacesByID() {
    let space = Space(id: 42, type: .normal)

    #expect(space.isEqual(Space(id: 42, type: .fullscreen)))
    #expect(!space.isEqual(Space(id: 43, type: .normal)))
    #expect(!space.isEqual("42"))
  }
}
