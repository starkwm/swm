import AppKit
import Testing

@testable import SwmLib

@Suite("WindowLifecycleHandler")
@MainActor
struct WindowLifecycleHandlerTests {
  @Test("created: adds a managed application's window and ignores unusable events")
  func createdAddsAManagedApplicationsWindowAndIgnoresUnusableEvents() throws {
    let pid = ProcessInfo.processInfo.processIdentifier
    var accessible = [CGWindowID]()
    let windows = Windows(
      workspace: Workspace(),
      focusedWindowID: nil,
      isObservable: { _ in true },
      makeApplication: {
        Application(for: $0, lookupConnection: { nil }, enumerateWindows: { _ in [] })
      },
      observeApplication: { _ in .success(()) },
      accessibleWindows: { application in
        accessible.map { Window(id: $0, application: application) }
      }
    )
    let process = SwmLib.Process(psn: .init(), pid: pid, name: "test", application: .current)
    _ = try #require(windows.manage(process))
    var snapshots = 0
    let tiling = makeTiling(
      windows: {
        snapshots += 1
        return [window(id: 2)]
      },
      memberships: { [2: [10]] }
    )
    let handler = WindowLifecycleHandler(windows: windows, tiling: tiling)

    accessible = [2]
    handler.handle(.created(pid, 0))
    handler.handle(.created(pid + 1, 2))
    #expect(windows.window(by: 2) == nil)
    #expect(snapshots == 0)

    handler.handle(.created(pid, 2))
    #expect(windows.window(by: 2) != nil)
    #expect(snapshots == 1)
  }

  @Test("destroyed: removes and invalidates the window once")
  func destroyedRemovesAndInvalidatesTheWindowOnce() throws {
    var tiled = [window(id: 1)]
    var snapshots = 0
    let tiling = makeTiling(
      windows: {
        snapshots += 1
        return tiled
      },
      memberships: { [1: [10]] }
    )
    let windows = windowsManaging([1])
    tiling.initialize()
    tiling.setLayout(.master, for: 10)
    let handler = WindowLifecycleHandler(windows: windows, tiling: tiling)
    let destroyed = try #require(windows.window(by: 1))

    tiled = []
    let before = snapshots
    handler.handle(.destroyed(destroyed))
    #expect(windows.window(by: 1) == nil)
    #expect(destroyed.id == 0)
    #expect(!tiling.isWindowTiled(1))
    #expect(snapshots == before + 1)

    // A repeated notification for the invalidated window is ignored.
    handler.handle(.destroyed(destroyed))
    #expect(snapshots == before + 1)
  }

  @Test("focused: tracks a managed window and defers an unknown one")
  func focusedTracksAManagedWindowAndDefersAnUnknownOne() {
    let windows = windowsManaging([1])
    let handler = WindowLifecycleHandler(windows: windows, tiling: makeTiling())

    handler.handle(.focused(1))
    #expect(windows.currentFocusedWindowID == 1)
    #expect(windows.lostFocusedWindowIDsSnapshot().isEmpty)

    handler.handle(.focused(0))
    handler.handle(.focused(99))
    #expect(windows.currentFocusedWindowID == 1)
    #expect(windows.lostFocusedWindowIDsSnapshot() == [99])
  }

  @Test("minimized/deminimized: reconcile the layout each time")
  func minimizedDeminimizedReconcileTheLayoutEachTime() throws {
    var minimized = false
    let tiling = makeTiling(
      windows: { [window(id: 1, isMinimized: minimized), window(id: 2)] },
      memberships: { [1: [10], 2: [10]] }
    )
    tiling.initialize()
    tiling.setLayout(.master, for: 10)
    let windows = windowsManaging([1, 2])
    let handler = WindowLifecycleHandler(windows: windows, tiling: tiling)
    let managedWindow = try #require(windows.window(by: 1))

    minimized = true
    handler.handle(.minimized(managedWindow))
    #expect(tiling.layoutPlan(for: layoutID(10))?.keys.sorted() == [2])

    minimized = false
    handler.handle(.deminimized(managedWindow))
    #expect(tiling.layoutPlan(for: layoutID(10))?.keys.sorted() == [1, 2])
  }

  /// Return windows that already manage the given IDs without an owning application.
  private func windowsManaging(_ ids: [CGWindowID]) -> Windows {
    let process = SwmLib.Process(
      psn: .init(),
      pid: ProcessInfo.processInfo.processIdentifier,
      name: "test",
      application: .current
    )
    let windows = Windows(
      workspace: Workspace(),
      focusedWindowID: nil,
      isObservable: { _ in true },
      makeApplication: {
        Application(for: $0, lookupConnection: { nil }, enumerateWindows: { _ in [] })
      },
      observeApplication: { _ in .success(()) },
      accessibleWindows: { _ in ids.map { Window(id: $0) } }
    )
    if let application = windows.manage(process) {
      windows.addWindows(for: application)
      // Unmanage the application so destruction does not schedule a rediscovery.
      windows.remove(application: application)
    }
    return windows
  }
}
