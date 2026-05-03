import Carbon
import Testing

@testable import SwmLib

@Suite("ApplicationEvent")
struct ApplicationEventTests {
  @Test("type: exposes application event types")
  func typeExposesApplicationEventTypes() {
    let psn = ProcessSerialNumber(highLongOfPSN: 1, lowLongOfPSN: 2)
    let process = Process(psn: psn, pid: 42, name: "Example")

    #expect(ApplicationEvent.launched(process).type == .applicationLaunched)
    #expect(ApplicationEvent.terminated(process).type == .applicationTerminated)
    #expect(ApplicationEvent.frontSwitched(process).type == .applicationFrontSwitched)
  }
}
