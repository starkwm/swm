import CoreGraphics
import Testing

@testable import SwmLib

@Suite("WindowEligibilityPolicy")
struct WindowEligibilityPolicyTests {
  static let cases: [(TilingWindowSnapshot, Set<UInt64>, WindowDisposition)] = [
    (window(id: 1), [10], .tiled),
    (window(id: 2), [10, 11], .floating(.multipleSpaces)),
    (window(id: 3), [12], .excluded(.nativeFullscreen)),
    (window(id: 4), [], .pending),
    (window(id: 8, displayID: nil), [10], .pending),
    (window(id: 5, subrole: "AXDialog"), [10], .excluded(.unsupportedSubrole)),
    (window(id: 6, isMovable: false), [10], .excluded(.notMovable)),
    (window(id: 7, isResizable: false), [10], .floating(.notResizable)),
    (window(id: 9, subrole: nil), [10], .excluded(.unsupportedSubrole)),
    (window(id: 10, subrole: nil, isMovable: false, hasUnavailableFacts: true), [10], .pending),
    (window(id: 11, isDialog: true), [10], .floating(.dialog)),
    (window(id: 12, isDialog: true), [10, 11], .floating(.multipleSpaces)),
    (window(id: 13, isDialog: true), [12], .excluded(.nativeFullscreen)),
    (window(id: 14, isResizable: false, isDialog: true), [10], .floating(.notResizable)),
  ]

  @Test("disposition: explains eligibility outcomes", arguments: cases)
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

  @Test("disposition: tiles a dialog-like window that a rule manages")
  func dispositionTilesDialogLikeWindowThatRuleManages() {
    let topology = SpaceTopology(
      spacesByID: [10: SpaceTopologyDescriptor(id: 10, displayID: "display", type: .normal)],
      visibleSpaceIDByDisplayID: ["display": 10],
      spaceIDsByWindowID: [1: [10]],
      displaysByID: [:]
    )

    #expect(
      WindowEligibilityPolicy.disposition(
        for: window(id: 1, isDialog: true),
        topology: topology,
        allowsDialogTiling: true
      ) == .tiled
    )
  }

  @Test(
    "isDialog: treats modal and closable windows without full screen as dialogs",
    arguments: [
      (false, true, true, false),
      (false, true, false, true),
      (true, true, true, true),
      (false, false, false, false),
    ]
  )
  func isDialogTreatsModalAndClosableWindowsWithoutFullScreenAsDialogs(
    isModal: Bool,
    hasCloseButton: Bool,
    isFullscreenButtonEnabled: Bool,
    expected: Bool
  ) {
    #expect(
      WindowEligibilityPolicy.isDialog(
        isModal: isModal,
        hasCloseButton: hasCloseButton,
        isFullscreenButtonEnabled: isFullscreenButtonEnabled
      ) == expected
    )
  }
}

private func window(
  id: CGWindowID,
  displayID: String? = "display",
  subrole: String? = "AXStandardWindow",
  isMovable: Bool = true,
  isResizable: Bool = true,
  isDialog: Bool = false,
  hasUnavailableFacts: Bool = false
) -> TilingWindowSnapshot {
  TilingWindowSnapshot(
    id: id,
    displayID: displayID,
    subrole: subrole,
    isMinimized: false,
    isMovable: isMovable,
    isResizable: isResizable,
    isDialog: isDialog,
    hasUnavailableFacts: hasUnavailableFacts
  )
}
