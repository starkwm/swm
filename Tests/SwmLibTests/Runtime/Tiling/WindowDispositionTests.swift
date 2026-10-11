import CoreGraphics
import Testing

@testable import SwmLib

@Suite("WindowEligibilityPolicy")
struct WindowEligibilityPolicyTests {
  @Test(
    "disposition: explains eligibility outcomes",
    arguments: [
      (window(id: 1), Set([UInt64(10)]), WindowDisposition.tiled),
      (window(id: 2), Set([UInt64(10), 11]), .floating(.multipleSpaces)),
      (window(id: 3), Set([UInt64(12)]), .excluded(.nativeFullscreen)),
      (window(id: 4), Set<UInt64>(), .pending),
      (window(id: 8, displayID: nil), Set([UInt64(10)]), .pending),
      (window(id: 5, subrole: "AXDialog"), Set([UInt64(10)]), .excluded(.unsupportedSubrole)),
      (window(id: 6, isMovable: false), Set([UInt64(10)]), .excluded(.notMovable)),
      (window(id: 7, isResizable: false), Set([UInt64(10)]), .excluded(.notResizable)),
    ]
  )
  func dispositionExplainsEligibilityOutcomes(
    snapshot: TilingWindowSnapshot,
    membership: Set<UInt64>,
    expected: WindowDisposition
  ) {
    let topology = SpaceTopology(
      spacesByID: [
        10: SpaceTopologyDescriptor(id: 10, displayID: "display", type: .normal),
        11: SpaceTopologyDescriptor(id: 11, displayID: "display", type: .normal),
        12: SpaceTopologyDescriptor(id: 12, displayID: "display", type: .fullscreen),
      ],
      visibleSpaceIDByDisplayID: ["display": 10],
      spaceIDsByWindowID: [snapshot.id: membership],
      displaysByID: [:]
    )

    #expect(WindowEligibilityPolicy.disposition(for: snapshot, topology: topology) == expected)
  }
}

private func window(
  id: CGWindowID,
  displayID: String? = "display",
  subrole: String = "AXStandardWindow",
  isMovable: Bool = true,
  isResizable: Bool = true
) -> TilingWindowSnapshot {
  TilingWindowSnapshot(
    id: id,
    displayID: displayID,
    subrole: subrole,
    isMinimized: false,
    isMovable: isMovable,
    isResizable: isResizable
  )
}
