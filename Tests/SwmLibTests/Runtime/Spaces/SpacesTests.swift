import StarkSkyLight
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
  @Test("snapshotTopology: carries failed and incomplete snapshots as unavailable")
  func snapshotTopologyCarriesFailedAndIncompleteSnapshotsAsUnavailable() throws {
    let spaces = Spaces(activeSpaceID: nil)
    let display = DisplaySpaces(
      id: .init(rawValue: "display"),
      spaces: [.init(id: .init(rawValue: 10), type: .desktop)],
      currentSpaceID: .init(rawValue: 10)
    )
    var snapshot = SpaceSnapshot(displays: [display], activeSpaceID: nil)
    var membershipReads = 0
    let read = {
      spaces.snapshotTopology(
        for: [1],
        snapshot: { snapshot },
        membership: { _ in
          membershipReads += 1
          return [10]
        },
        displays: { [:] }
      )
    }
    #expect(read() == nil)
    #expect(membershipReads == 0)
    #expect(
      spaces.snapshotTopology(for: [], snapshot: { throw TestTopologyError.unavailable }) == nil
    )
    snapshot = SpaceSnapshot(displays: [display], activeSpaceID: .init(rawValue: 10))
    let topology = try #require(read())
    #expect(topology.spacesByID[10]?.type == .normal)
    #expect(topology.visibleSpaceIDByDisplayID == ["display": 10])
    #expect(topology.spaceIDsByWindowID == [1: [10]])
    #expect(
      spaces.snapshotTopology(
        for: [1],
        snapshot: { snapshot },
        membership: { _ in throw TestTopologyError.unavailable },
        displays: { [:] }
      ) == nil
    )
  }

}

private enum TestTopologyError: Error {
  case unavailable
}
