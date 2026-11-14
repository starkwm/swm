import AppKit
import Testing

@testable import SwmLib

@Suite("ApplicationLifecycleHandler")
@MainActor
struct ApplicationLifecycleHandlerTests {
  @Test("launched: manages a ready application, tiles its windows, and replays a front switch")
  func launchedManagesAReadyApplicationTilesItsWindowsAndReplaysAFrontSwitch() {
    let process = readyProcess()
    let windows = managingWindows()
    windows.addLostFrontSwitchedEvent(for: process.pid)
    var snapshots = 0
    let tiling = makeTiling(
      windows: {
        snapshots += 1
        return [window(id: 1)]
      },
      memberships: { [1: [10]] }
    )
    var posted = [String]()
    let handler = ApplicationLifecycleHandler(
      workspace: Workspace(),
      processes: Processes(tracking: [process]),
      windows: windows,
      tiling: tiling,
      postEvent: { posted.append(describe($0)) }
    )

    handler.handle(.launched(process))

    #expect(windows.application(by: process.pid) != nil)
    #expect(windows.window(by: 1) != nil)
    #expect(snapshots == 1)
    #expect(tiling.setLayout(.master, for: 10))
    #expect(tiling.isWindowTiled(1))
    #expect(posted == ["frontSwitched \(process.pid)"])
    #expect(!windows.removeLostFrontSwitchedEvent(for: process.pid))
  }

  @Test("terminated: forgets the application and invalidates its windows")
  func terminatedForgetsTheApplicationAndInvalidatesItsWindows() throws {
    let process = readyProcess()
    let windows = managingWindows()
    var tiledWindows = [window(id: 1)]
    let tiling = makeTiling(windows: { tiledWindows }, memberships: { [1: [10]] })
    let handler = ApplicationLifecycleHandler(
      workspace: Workspace(),
      processes: Processes(tracking: [process]),
      windows: windows,
      tiling: tiling,
      postEvent: { Issue.record("unexpected event \(describe($0))") }
    )
    handler.handle(.launched(process))
    tiling.setLayout(.master, for: 10)
    let managedWindow = try #require(windows.window(by: 1))

    tiledWindows = []
    handler.handle(.terminated(process))

    #expect(windows.application(by: process.pid) == nil)
    #expect(windows.window(by: 1) == nil)
    #expect(managedWindow.id == 0)
    #expect(managedWindow.application == nil)
    #expect(!tiling.isWindowTiled(1))
  }

  @Test("frontSwitched: records a switch to an application that is not managed yet")
  func frontSwitchedRecordsASwitchToAnApplicationThatIsNotManagedYet() {
    let process = SwmLib.Process(
      psn: ProcessSerialNumber(highLongOfPSN: 0, lowLongOfPSN: 9),
      pid: .max,
      name: "-"
    )
    let windows = Windows(
      workspace: Workspace(),
      focusedWindowID: nil,
      discoveryRetryPolicy: DiscoveryRetryPolicy(
        initialDelay: .milliseconds(1),
        maximumDelay: .milliseconds(1),
        maximumRetries: 0
      )
    )
    let handler = ApplicationLifecycleHandler(
      workspace: Workspace(),
      processes: Processes(tracking: [process]),
      windows: windows,
      tiling: makeTiling(),
      postEvent: { Issue.record("unexpected event \(describe($0))") }
    )

    handler.handle(.frontSwitched(process))

    #expect(windows.application(by: process.pid) == nil)
    #expect(windows.removeLostFrontSwitchedEvent(for: process.pid))
  }

  @Test("launched: retries a process that has no AppKit application yet")
  func launchedRetriesAProcessThatHasNoAppKitApplicationYet() async {
    // No running application has this process ID, so AppKit cannot resolve it.
    let process = SwmLib.Process(
      psn: ProcessSerialNumber(highLongOfPSN: 0, lowLongOfPSN: 7),
      pid: .max,
      name: "-"
    )
    let windows = Windows(
      workspace: Workspace(),
      focusedWindowID: nil,
      discoveryRetryPolicy: DiscoveryRetryPolicy(
        initialDelay: .milliseconds(1),
        maximumDelay: .milliseconds(1),
        maximumRetries: 1
      )
    )
    var relaunches = 0
    let handler = ApplicationLifecycleHandler(
      workspace: Workspace(),
      processes: Processes(tracking: [process]),
      windows: windows,
      tiling: makeTiling(),
      postEvent: { event in
        guard case .application(.launched(let relaunched)) = event, relaunched === process else {
          Issue.record("unexpected event \(event)")
          return
        }
        relaunches += 1
      }
    )

    handler.handle(.launched(process))
    await windows.waitForDiscoveryRetries()

    #expect(relaunches == 1)
    #expect(windows.application(by: process.pid) == nil)
  }
}

/// Running application that reports itself as a launched, regular app.
private final class ReadyApplication: NSRunningApplication {
  override var isFinishedLaunching: Bool { true }
  override var activationPolicy: NSApplication.ActivationPolicy { .regular }
  override var localizedName: String? { "Ready" }
}

extension ReadyApplication: @unchecked Sendable {}

@MainActor
private func readyProcess() -> SwmLib.Process {
  SwmLib.Process(
    psn: ProcessSerialNumber(highLongOfPSN: 0, lowLongOfPSN: 8),
    pid: ProcessInfo.processInfo.processIdentifier,
    name: "Ready",
    application: ReadyApplication()
  )
}

/// Windows that manage any process and expose one accessible window with ID 1.
@MainActor
private func managingWindows() -> Windows {
  Windows(
    workspace: Workspace(),
    focusedWindowID: nil,
    makeApplication: {
      Application(for: $0, lookupConnection: { 42 }, enumerateWindows: { _ in [1] })
    },
    observeApplication: { _ in .success(()) },
    accessibleWindows: { [Window(id: 1, application: $0)] }
  )
}

@MainActor
private func describe(_ event: RuntimeEvent) -> String {
  switch event {
  case .application(.launched(let process)): "launched \(process.pid)"
  case .application(.frontSwitched(let process)): "frontSwitched \(process.pid)"
  default: "\(event)"
  }
}
