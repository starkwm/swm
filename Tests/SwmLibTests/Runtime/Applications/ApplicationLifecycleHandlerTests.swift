import AppKit
import Testing

@testable import SwmLib

@Suite("ApplicationLifecycleHandler")
@MainActor
struct ApplicationLifecycleHandlerTests {
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
