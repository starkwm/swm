import Testing

@testable import SwmLib

@Suite("Space")
struct SpaceTests {
  @Test("equality: compares spaces by id")
  func equalityComparesSpacesById() {
    let space = Space(id: 42, type: .normal)

    #expect(space == Space(id: 42, type: .fullscreen))
    #expect(space != Space(id: 43, type: .normal))
  }
}
