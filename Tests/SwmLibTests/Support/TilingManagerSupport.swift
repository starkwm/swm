@testable import SwmLib

@MainActor
func makeTestTilingManager(
  spaceManager: SpaceManager,
  windows: [TilingWindowSnapshot] = [],
  topology: SpaceTopology = SpaceTopology(
    spacesByID: [:],
    visibleSpaceIDByDisplayID: [:],
    spaceIDsByWindowID: [:],
    displaysByID: [:]
  )
) -> TilingManager {
  TilingManager(
    snapshot: {
      TilingReconciliationSnapshot(
        windows: windows,
        topology: topology
      )
    },
    spaceManager: spaceManager
  )
}
