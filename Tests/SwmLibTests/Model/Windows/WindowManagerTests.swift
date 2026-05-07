import Darwin
import Testing

@testable import SwmLib

@Suite("WindowManager")
struct WindowManagerTests {
  @Test("lost front-switched events are consumed once")
  func lostFrontSwitchedEventsAreConsumedOnce() {
    let manager = WindowManager(workspace: Workspace(), focusedWindowID: nil)
    let processID: pid_t = 42

    #expect(manager.removeLostFrontSwitchedEvent(for: processID) == false)

    manager.addLostFrontSwitchedEvent(for: processID)

    #expect(manager.removeLostFrontSwitchedEvent(for: processID))
    #expect(manager.removeLostFrontSwitchedEvent(for: processID) == false)
  }
}
