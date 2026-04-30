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

  @Test("post accepts window events")
  func postAcceptsWindowEvents() {
    EventManager.shared.post(.window(.created(42, 1)))
    EventManager.shared.post(.window(.focused(1)))
    EventManager.shared.post(.window(.moved(1)))
    EventManager.shared.post(.window(.resized(1)))
  }

  @Test("runtime event exposes nested event type")
  func runtimeEventExposesNestedEventType() {
    let space = Space(id: 1, type: .normal)
    let event = RuntimeEvent.space(.changed(space))

    #expect(event.type == .spaceChanged)
  }

  @Test("application events expose event types")
  func applicationEventsExposeEventTypes() {
    let psn = ProcessSerialNumber(highLongOfPSN: 1, lowLongOfPSN: 2)
    let process = Process(psn: psn, pid: 42, name: "Example")

    #expect(ApplicationEvent.launched(process).type == .applicationLaunched)
    #expect(ApplicationEvent.terminated(process).type == .applicationTerminated)
    #expect(ApplicationEvent.frontSwitched(process).type == .applicationFrontSwitched)
  }

  @Test("window events expose event types")
  func windowEventsExposeEventTypes() {
    #expect(WindowEvent.created(42, 1).type == .windowCreated)
    #expect(WindowEvent.focused(1).type == .windowFocused)
    #expect(WindowEvent.moved(1).type == .windowMoved)
    #expect(WindowEvent.resized(1).type == .windowResized)
  }

  @Test("space events expose event types")
  func spaceEventsExposeEventTypes() {
    let space = Space(id: 1, type: .normal)

    #expect(SpaceEvent.changed(space).type == .spaceChanged)
  }
}
