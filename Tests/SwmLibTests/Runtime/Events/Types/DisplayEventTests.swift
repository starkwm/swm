import Testing

@testable import SwmLib

@Suite("DisplayEvent")
struct DisplayEventTests {
  @Test("type: exposes display event types")
  func typeExposesDisplayEventTypes() {
    #expect(DisplayEvent.changed.type == .displayChanged)
  }
}
