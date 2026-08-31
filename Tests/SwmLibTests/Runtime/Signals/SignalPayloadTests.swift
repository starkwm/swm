import Testing

@testable import SwmLib

@Suite("SignalPayload")
struct SignalPayloadTests {
  @Test("application: maps process environment")
  func applicationMapsProcessEnvironment() {
    let payload = SignalPayload.application(
      event: .applicationFrontSwitched,
      processID: 123,
      app: "Safari",
      active: true
    )

    #expect(payload.event == .applicationFrontSwitched)
    #expect(payload.app == "Safari")
    #expect(payload.active == true)
    #expect(payload.environment["SWM_PROCESS_ID"] == "123")
  }

  @Test("spaceChanged: maps current and recent space environment")
  func spaceChangedMapsEnvironment() {
    let payload = SignalPayload.spaceChanged(
      space: Space(id: 10),
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

  @Test("displayChanged: maps display environment")
  func displayChangedMapsEnvironment() {
    let payload = SignalPayload.displayChanged(currentID: "display-a", recentID: "display-b")

    #expect(payload.event == .displayChanged)
    #expect(payload.environment["SWM_DISPLAY_ID"] == "display-a")
    #expect(payload.environment["SWM_RECENT_DISPLAY_ID"] == "display-b")
  }

  @Test("display: maps reconfiguration environment")
  func displayMapsReconfigurationEnvironment() {
    let payload = SignalPayload.display(
      event: .displayMoved,
      displayID: 42,
      currentID: "display-a",
      recentID: "display-b"
    )

    #expect(payload.event == .displayMoved)
    #expect(payload.environment["SWM_EVENT_DISPLAY_ID"] == "42")
    #expect(payload.environment["SWM_DISPLAY_ID"] == "display-a")
    #expect(payload.environment["SWM_RECENT_DISPLAY_ID"] == "display-b")
  }
}
