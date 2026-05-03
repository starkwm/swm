import Testing

@testable import SwmLib

@Suite("RuntimeEvent")
struct RuntimeEventTests {
  @Test("type: exposes nested runtime event type")
  func typeExposesNestedRuntimeEventType() {
    let space = Space(id: 1, type: .normal)
    let event = RuntimeEvent.space(.changed(space))

    #expect(event.type == .spaceChanged)
  }
}
