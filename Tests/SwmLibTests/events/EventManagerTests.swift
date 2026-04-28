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
}
