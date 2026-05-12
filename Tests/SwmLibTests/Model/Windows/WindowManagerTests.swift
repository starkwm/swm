import CoreGraphics
import Darwin
import Testing

@testable import SwmLib

@Suite("WindowManager")
struct WindowManagerTests {
  @Test("addLostFrontSwitchedEvent/removeLostFrontSwitchedEvent: consumes once")
  func addAndRemoveLostFrontSwitchedEventConsumesOnce() {
    let manager = WindowManager(workspace: Workspace())
    let processID: pid_t = 42

    #expect(manager.removeLostFrontSwitchedEvent(for: processID) == false)

    manager.addLostFrontSwitchedEvent(for: processID)

    #expect(manager.removeLostFrontSwitchedEvent(for: processID))
    #expect(manager.removeLostFrontSwitchedEvent(for: processID) == false)
  }

  @Test("addLostFocusedEvent/removeLostFocusedEvent: tracks and consumes once")
  func addAndRemoveLostFocusedEventTracksAndConsumesOnce() {
    let manager = WindowManager(workspace: Workspace())
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
