import CoreGraphics
import Darwin
import Testing

@testable import SwmLib

@Suite("Windows")
@MainActor
struct WindowsTests {
  @Test("addLostFrontSwitchedEvent/removeLostFrontSwitchedEvent: consumes once")
  func addAndRemoveLostFrontSwitchedEventConsumesOnce() {
    let windows = Windows(workspace: Workspace())
    let processID: pid_t = 42

    #expect(windows.removeLostFrontSwitchedEvent(for: processID) == false)

    windows.addLostFrontSwitchedEvent(for: processID)

    #expect(windows.removeLostFrontSwitchedEvent(for: processID))
    #expect(windows.removeLostFrontSwitchedEvent(for: processID) == false)
  }

  @Test("addLostFocusedEvent/removeLostFocusedEvent: tracks and consumes once")
  func addAndRemoveLostFocusedEventTracksAndConsumesOnce() {
    let windows = Windows(workspace: Workspace())
    let windowID: CGWindowID = 42

    #expect(windows.removeLostFocusedEvent(for: windowID) == false)

    windows.addLostFocusedEvent(for: windowID)

    #expect(windows.removeLostFocusedEvent(for: windowID))
    #expect(windows.removeLostFocusedEvent(for: windowID) == false)
  }
}
