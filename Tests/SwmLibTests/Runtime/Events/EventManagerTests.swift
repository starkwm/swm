import Carbon
import Testing

@testable import SwmLib

@Suite("EventManager")
struct EventManagerTests {
  @Test("post: accepts application events")
  func postAcceptsApplicationEvents() {
    let psn = ProcessSerialNumber(highLongOfPSN: 1, lowLongOfPSN: 2)
    let process = Process(psn: psn, pid: 42, name: "Example")

    EventManager.shared.configure(processLookup: ProcessManager())
    EventManager.shared.post(.application(.launched(process)))
  }

  @Test("post: accepts space events")
  func postAcceptsSpaceEvents() {
    let space = Space(id: 1, type: .normal)

    EventManager.shared.post(.space(.changed(space)))
  }

  @Test("post: accepts window events")
  func postAcceptsWindowEvents() {
    EventManager.shared.post(.window(.created(42, 1)))
    EventManager.shared.post(.window(.focused(1)))
    EventManager.shared.post(.window(.moved(1)))
    EventManager.shared.post(.window(.resized(1)))
  }
}
