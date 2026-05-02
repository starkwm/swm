import Testing

@testable import SwmLib

@Suite("WindowEvent")
struct WindowEventTests {
  @Test("type: exposes window event types")
  func typeExposesWindowEventTypes() {
    #expect(WindowEvent.created(42, 1).type == .windowCreated)
    #expect(WindowEvent.focused(1).type == .windowFocused)
    #expect(WindowEvent.moved(1).type == .windowMoved)
    #expect(WindowEvent.resized(1).type == .windowResized)
  }
}
