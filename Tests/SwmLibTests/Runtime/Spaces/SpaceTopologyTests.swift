import CoreGraphics
import Testing

@testable import SwmLib

@Suite("SpaceTopology")
struct SpaceTopologyTests {
  @Test("layout IDs: keeps separate Spaces on their physical displays")
  func layoutIDsKeepSeparateSpacesOnTheirPhysicalDisplays() {
    let topology = makeTopology(
      spacesByID: [
        10: SpaceTopologyDescriptor(id: 10, displayID: "display-a", type: .normal),
        20: SpaceTopologyDescriptor(id: 20, displayID: "display-b", type: .normal),
      ],
      visibleSpaceIDByDisplayID: ["display-a": 10, "display-b": 20],
      spaceIDsByWindowID: [1: [10], 2: [20]]
    )

    #expect(
      topology.layoutIDs == [
        SpaceLayoutID(spaceID: 10, displayID: "display-a"),
        SpaceLayoutID(spaceID: 20, displayID: "display-b"),
      ]
    )
    #expect(topology.visibleLayoutIDs == topology.layoutIDs)
    #expect(
      topology.layoutID(for: 1, on: "display-a")
        == SpaceLayoutID(spaceID: 10, displayID: "display-a")
    )
    #expect(topology.layoutID(for: 1, on: "display-b") == nil)
  }

  @Test("layout IDs: expands a shared Space across physical displays")
  func layoutIDsExpandSharedSpaceAcrossPhysicalDisplays() {
    let topology = makeTopology(
      spacesByID: [
        10: SpaceTopologyDescriptor(id: 10, displayID: "shared", type: .normal),
        11: SpaceTopologyDescriptor(id: 11, displayID: "shared", type: .normal),
      ],
      visibleSpaceIDByDisplayID: ["shared": 10],
      spaceIDsByWindowID: [1: [10], 2: [10]]
    )
    let visibleLayoutIDs: Set<SpaceLayoutID> = [
      SpaceLayoutID(spaceID: 10, displayID: "display-a"),
      SpaceLayoutID(spaceID: 10, displayID: "display-b"),
    ]

    #expect(
      topology.layoutIDs
        == visibleLayoutIDs.union([
          SpaceLayoutID(spaceID: 11, displayID: "display-a"),
          SpaceLayoutID(spaceID: 11, displayID: "display-b"),
        ])
    )
    #expect(topology.visibleLayoutIDs == visibleLayoutIDs)
    #expect(
      topology.layoutID(for: 1, on: "display-a")
        == SpaceLayoutID(spaceID: 10, displayID: "display-a")
    )
    #expect(
      topology.layoutID(for: 2, on: "display-b")
        == SpaceLayoutID(spaceID: 10, displayID: "display-b")
    )
  }

  private func makeTopology(
    spacesByID: [UInt64: SpaceTopologyDescriptor],
    visibleSpaceIDByDisplayID: [String: UInt64],
    spaceIDsByWindowID: [CGWindowID: Set<UInt64>]
  ) -> SpaceTopology {
    SpaceTopology(
      spacesByID: spacesByID,
      visibleSpaceIDByDisplayID: visibleSpaceIDByDisplayID,
      spaceIDsByWindowID: spaceIDsByWindowID,
      displaysByID: [
        "display-a": SpaceTopologyDisplay(
          visibleFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800)
        ),
        "display-b": SpaceTopologyDisplay(
          visibleFrame: CGRect(x: 1_000, y: 0, width: 800, height: 800)
        ),
      ]
    )
  }
}
