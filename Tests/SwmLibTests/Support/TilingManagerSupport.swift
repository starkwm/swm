import CoreGraphics

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

@MainActor
func makeManager(
  windows: [TilingWindowSnapshot] = [window(id: 1)],
  memberships: [CGWindowID: Set<UInt64>] = [1: [10]],
  visibleSpaceID: UInt64 = 10,
  frameReconciler: WindowFrameReconciler? = nil
) -> TilingManager {
  makeManager(
    windows: { windows },
    memberships: { memberships },
    visibleSpaceID: visibleSpaceID,
    frameReconciler: frameReconciler
  )
}

@MainActor
func makeManager(
  windows: @escaping () -> [TilingWindowSnapshot],
  memberships: @escaping () -> [CGWindowID: Set<UInt64>],
  visibleSpaceID: UInt64 = 10,
  frameReconciler: WindowFrameReconciler? = nil
) -> TilingManager {
  let spaceManager = SpaceManager(activeSpaceID: nil)
  return TilingManager(
    snapshot: {
      TilingReconciliationSnapshot(
        windows: windows(),
        topology: SpaceTopology(
          spacesByID: [
            10: SpaceTopologyDescriptor(id: 10, displayID: "display", type: .normal),
            11: SpaceTopologyDescriptor(id: 11, displayID: "display", type: .normal),
            12: SpaceTopologyDescriptor(id: 12, displayID: "display", type: .fullscreen),
          ],
          visibleSpaceIDByDisplayID: ["display": visibleSpaceID],
          spaceIDsByWindowID: memberships(),
          displaysByID: [
            "display": SpaceTopologyDisplay(
              visibleFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800)
            )
          ]
        )
      )
    },
    spaceManager: spaceManager,
    frameReconciler: frameReconciler
  )
}

@MainActor
func makeSharedSpaceManager(
  windows: @escaping () -> [TilingWindowSnapshot]
) -> TilingManager {
  makeSharedSpaceManager(
    windows: windows,
    displays: {
      [
        "display-a": SpaceTopologyDisplay(
          visibleFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800)
        ),
        "display-b": SpaceTopologyDisplay(
          visibleFrame: CGRect(x: 1_000, y: 0, width: 800, height: 800)
        ),
      ]
    }
  )
}

@MainActor
func makeSharedSpaceManager(
  windows: @escaping () -> [TilingWindowSnapshot],
  displays: @escaping () -> [String: SpaceTopologyDisplay]
) -> TilingManager {
  let spaceManager = SpaceManager(activeSpaceID: nil)
  return TilingManager(
    snapshot: {
      let windows = windows()
      return TilingReconciliationSnapshot(
        windows: windows,
        topology: SpaceTopology(
          spacesByID: [
            10: SpaceTopologyDescriptor(id: 10, displayID: "Main", type: .normal),
            11: SpaceTopologyDescriptor(id: 11, displayID: "Main", type: .normal),
          ],
          visibleSpaceIDByDisplayID: ["Main": 10],
          spaceIDsByWindowID: Dictionary(
            uniqueKeysWithValues: windows.map { ($0.id, Set([UInt64(10)])) }
          ),
          displaysByID: displays()
        )
      )
    },
    spaceManager: spaceManager
  )
}

func layoutID(
  _ spaceID: UInt64,
  displayID: String = "display"
) -> TilingLayoutID {
  TilingLayoutID(spaceID: spaceID, displayID: displayID)
}

func window(
  id: CGWindowID,
  displayID: String? = "display",
  isMinimized: Bool = false
) -> TilingWindowSnapshot {
  TilingWindowSnapshot(
    id: id,
    displayID: displayID,
    subrole: "AXStandardWindow",
    isMinimized: isMinimized,
    isMovable: true,
    isResizable: true
  )
}
