import ApplicationServices
import Carbon
import Testing

@testable import SwmLib

@Suite("EventManager")
struct EventManagerTests {
  @Test("post accepts application events")
  func postAcceptsApplicationEvents() {
    let psn = ProcessSerialNumber(highLongOfPSN: 1, lowLongOfPSN: 2)
    let process = Process(psn: psn, pid: 42, name: "Example")

    EventManager.shared.post(.application(.launched(process)))
  }

  @Test("post accepts space events")
  func postAcceptsSpaceEvents() {
    let space = Space(id: 1, type: .normal)

    EventManager.shared.post(.space(.changed(space)))
  }

  @Test("post accepts window identifier events")
  func postAcceptsWindowIdentifierEvents() {
    let element = AXUIElementCreateSystemWide()

    EventManager.shared.post(windowIdentifierEvent: .focused, withWindowElement: element)
    EventManager.shared.post(windowCreatedWithElement: element)
  }
}
