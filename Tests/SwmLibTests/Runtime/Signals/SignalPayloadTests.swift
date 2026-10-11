import Testing

@testable import SwmLib

@Suite("SignalPayload")
struct SignalPayloadTests {
  @Test("spaceChanged: maps current and recent space environment")
  func spaceChangedMapsCurrentAndRecentSpaceEnvironment() {
    let payload = SignalPayload.spaceChanged(
      space: Space(id: 10, type: .normal),
      currentIndex: 2,
      recentSpaceID: 8,
      recentIndex: 1
    )

    #expect(payload.event == .spaceChanged)
    #expect(payload.environment["SWM_SPACE_ID"] == "10")
    #expect(payload.environment["SWM_SPACE_INDEX"] == "2")
    #expect(payload.environment["SWM_RECENT_SPACE_ID"] == "8")
    #expect(payload.environment["SWM_RECENT_SPACE_INDEX"] == "1")
  }

  @Test(
    "displayChanged/display: preserves current and recent display context",
    arguments: [false, true]
  )
  func displayChangedDisplayPreservesCurrentAndRecentDisplayContext(reconfiguration: Bool) {
    let payload =
      reconfiguration
      ? SignalPayload.display(
        event: .displayMoved,
        displayID: 42,
        currentID: "display-a",
        recentID: "display-b"
      )
      : SignalPayload.displayChanged(currentID: "display-a", recentID: "display-b")
    #expect(payload.environment["SWM_DISPLAY_ID"] == "display-a")
    #expect(payload.environment["SWM_RECENT_DISPLAY_ID"] == "display-b")
  }
}
