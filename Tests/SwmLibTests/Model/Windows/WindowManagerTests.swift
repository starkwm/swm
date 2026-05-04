import Testing

@testable import SwmLib

@Suite("WindowManager")
struct WindowManagerTests {
  @Test("init: starts without focused window")
  func initStartsWithoutFocusedWindow() {
    let manager = WindowManager(workspace: Workspace())

    #expect(manager.currentFocusedWindowID == nil)
    #expect(manager.lastFocusedWindowID == nil)
  }

  @Test("focusedWindowDidChange: updates current and last window")
  func focusedWindowDidChangeUpdatesCurrentAndLastWindow() {
    let manager = WindowManager(workspace: Workspace())

    manager.focusedWindowDidChange(to: 1)
    manager.focusedWindowDidChange(to: 2)

    #expect(manager.currentFocusedWindowID == 2)
    #expect(manager.lastFocusedWindowID == 1)
  }

  @Test("focusedWindowDidChange: keeps last window for repeated focused window")
  func focusedWindowDidChangeKeepsLastWindowForRepeatedFocusedWindow() {
    let manager = WindowManager(workspace: Workspace())

    manager.focusedWindowDidChange(to: 1)
    manager.focusedWindowDidChange(to: 2)
    manager.focusedWindowDidChange(to: 2)

    #expect(manager.currentFocusedWindowID == 2)
    #expect(manager.lastFocusedWindowID == 1)
  }

  @Test("focusedWindowDidChange: ignores zero window")
  func focusedWindowDidChangeIgnoresZeroWindow() {
    let manager = WindowManager(workspace: Workspace())

    manager.focusedWindowDidChange(to: 1)
    manager.focusedWindowDidChange(to: 0)

    #expect(manager.currentFocusedWindowID == 1)
    #expect(manager.lastFocusedWindowID == nil)
  }
}
