import CoreGraphics

@testable import SwmLib

@MainActor
func makeTestTiling(
  spaces: Spaces,
  windows: [TilingWindowSnapshot] = [],
  topology: SpaceTopology = SpaceTopology(
    spacesByID: [:],
    visibleSpaceIDByDisplayID: [:],
    spaceIDsByWindowID: [:],
    displaysByID: [:]
  )
) -> Tiling {
  Tiling(
    snapshot: {
      TilingReconciliationSnapshot(
        windows: windows,
        topology: topology
      )
    },
    spaces: spaces
  )
}

@MainActor
func makeTiling(
  windows: [TilingWindowSnapshot] = [window(id: 1)],
  memberships: [CGWindowID: Set<UInt64>] = [1: [10]],
  visibleSpaceID: UInt64 = 10,
  frameReconciler: WindowFrameReconciler? = nil
) -> Tiling {
  makeTiling(
    windows: { windows },
    memberships: { memberships },
    visibleSpaceID: visibleSpaceID,
    frameReconciler: frameReconciler
  )
}

@MainActor
func makeTiling(
  windows: @escaping () -> [TilingWindowSnapshot],
  memberships: @escaping () -> [CGWindowID: Set<UInt64>],
  visibleSpaceID: UInt64 = 10,
  frameReconciler: WindowFrameReconciler? = nil
) -> Tiling {
  let spaces = Spaces(activeSpaceID: nil)
  return Tiling(
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
    spaces: spaces,
    frameReconciler: frameReconciler,
    windowSpaceMembership: memberships
  )
}

@MainActor
func makeSharedSpaceTiling(
  windows: @escaping () -> [TilingWindowSnapshot]
) -> Tiling {
  makeSharedSpaceTiling(
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
func makeSharedSpaceTiling(
  windows: @escaping () -> [TilingWindowSnapshot],
  displays: @escaping () -> [String: SpaceTopologyDisplay]
) -> Tiling {
  let spaces = Spaces(activeSpaceID: nil)
  return Tiling(
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
    spaces: spaces
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
