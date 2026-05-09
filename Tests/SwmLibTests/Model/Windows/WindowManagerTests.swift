import CoreGraphics
import Darwin
import Testing

@testable import SwmLib

@Suite("WindowManager")
struct WindowManagerTests {
  @Test("focusedWindowID: resolves current focused window live")
  func focusedWindowIDResolvesCurrentFocusedWindowLive() {
    let manager = WindowManager(
      workspace: Workspace(),
      focusedWindowIDResolver: { 42 }
    )

    #expect(manager.focusedWindowID() == 42)
  }

  @Test("lost front-switched events are consumed once")
  func lostFrontSwitchedEventsAreConsumedOnce() {
    let manager = WindowManager(workspace: Workspace(), focusedWindowIDResolver: { nil })
    let processID: pid_t = 42

    #expect(manager.removeLostFrontSwitchedEvent(for: processID) == false)

    manager.addLostFrontSwitchedEvent(for: processID)

    #expect(manager.removeLostFrontSwitchedEvent(for: processID))
    #expect(manager.removeLostFrontSwitchedEvent(for: processID) == false)
  }

  @Test("lost focused events are tracked and consumed once")
  func lostFocusedEventsAreTrackedAndConsumedOnce() {
    let manager = WindowManager(workspace: Workspace(), focusedWindowIDResolver: { nil })
    let windowID: CGWindowID = 42

    #expect(manager.containsLostFocusedEvent(for: windowID) == false)
    #expect(manager.removeLostFocusedEvent(for: windowID) == false)

    manager.addLostFocusedEvent(for: windowID)

    #expect(manager.containsLostFocusedEvent(for: windowID))
    #expect(manager.removeLostFocusedEvent(for: windowID))
    #expect(manager.containsLostFocusedEvent(for: windowID) == false)
    #expect(manager.removeLostFocusedEvent(for: windowID) == false)
  }
}
