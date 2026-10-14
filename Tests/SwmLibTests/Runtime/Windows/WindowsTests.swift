import AppKit
import CoreGraphics
import Darwin
import Testing

@testable import SwmLib

@Suite("Windows")
@MainActor
struct WindowsTests {
  @Test(
    "discover: retains AX windows and retries only for the same live process",
    arguments: ["recovered", "terminated", "replaced"]
  )
  func discoverRetainsAXWindowsAndRetriesOnlyForTheSameLiveProcess(outcome: String) async throws {
    let process = Process(
      psn: .init(),
      pid: ProcessInfo.processInfo.processIdentifier,
      name: "test",
      application: .current
    )
    let replacement = Process(psn: .init(), pid: process.pid, name: "replacement")
    var tracked = process
    var lookups = 0
    var enumerations = 0
    var creations = 0
    var recoveries = 0
    let windows = Windows(
      workspace: Workspace(),
      focusedWindowID: nil,
      isObservable: { _ in true },
      makeApplication: { process in
        creations += 1
        return Application(
          for: process,
          lookupConnection: {
            lookups += 1
            return lookups == 1 ? nil : 42
          },
          enumerateWindows: { connection in
            #expect(connection == 42)
            enumerations += 1
            return [1, 2]
          }
        )
      },
      observeApplication: { _ in .success(()) },
      accessibleWindows: { application in
        (enumerations == 0 ? [1] : [1, 2]).map { Window(id: $0, application: application) }
      }
    )
    let discover = {
      windows.discover(process, resolveProcess: { tracked }, onRecovery: { recoveries += 1 })
    }
    discover()
    #expect(windows.window(by: 1) != nil)
    #expect(windows.window(by: 2) == nil)
    #expect(enumerations == 0)
    // Repeated notifications share the pending retry.
    windows.retryDiscovery(for: process, resolveProcess: { tracked }, retry: discover)
    process.terminated = outcome == "terminated"
    if outcome == "replaced" { tracked = replacement }
    await windows.waitForDiscoveryRetries()
    let recovered = outcome == "recovered"
    #expect((windows.window(by: 2) != nil) == recovered)
    #expect(lookups == (recovered ? 2 : 1))
    #expect(enumerations == (recovered ? 1 : 0))
    #expect(creations == 1)
    #expect(recoveries == (recovered ? 1 : 0))
  }

  @Test("discover: retries recoverable startup registration and stops permanent failures")
  func discoverRetriesRecoverableStartupRegistrationAndStopsPermanentFailures() async throws {
    let process = Process(
      psn: .init(),
      pid: ProcessInfo.processInfo.processIdentifier,
      name: "test",
      application: .current
    )
    for permanent in [false, true] {
      var attempts = 0
      let windows = Windows(
        workspace: Workspace(),
        focusedWindowID: nil,
        isObservable: { _ in true },
        makeApplication: {
          Application(for: $0, lookupConnection: { 42 }, enumerateWindows: { _ in [1] })
        },
        observeApplication: { application in
          attempts += 1
          return application.observe(addNotification: { notification in
            guard attempts == 1 else { return .success }
            if notification == kAXCreatedNotification {
              return permanent ? .notificationUnsupported : .cannotComplete
            }
            // A later permanent failure must not erase an earlier recoverable one.
            return notification == kAXWindowResizedNotification
              ? .notificationUnsupported : .success
          })
        },
        accessibleWindows: { [Window(id: 1, application: $0)] }
      )
      windows.discover(process, resolveProcess: { process }, onRecovery: {})
      #expect(windows.window(by: 1) == nil)
      await windows.waitForDiscoveryRetries()
      #expect(attempts == (permanent ? 1 : 2))
      #expect((windows.window(by: 1) != nil) == !permanent)
    }
  }

  @Test(
    "discover: termination or replacement prevents a pending startup retry",
    arguments: [false, true]
  )
  func discoverTerminationOrReplacementPreventsAPendingStartupRetry(replaced: Bool) async {
    let process = Process(
      psn: .init(),
      pid: ProcessInfo.processInfo.processIdentifier,
      name: "test",
      application: .current
    )
    let replacement = Process(psn: .init(), pid: process.pid, name: "replacement")
    var attempts = 0
    let windows = Windows(
      workspace: Workspace(),
      focusedWindowID: nil,
      isObservable: { _ in true },
      makeApplication: { Application(for: $0, lookupConnection: { nil }) },
      observeApplication: { application in
        attempts += 1
        return application.observe(addNotification: { _ in .cannotComplete })
      },
      accessibleWindows: { _ in
        Issue.record("Discovery ran after failed observation")
        return []
      }
    )
    windows.discover(
      process,
      resolveProcess: { replaced ? replacement : process },
      onRecovery: {
        Issue.record("Retried a terminated or replaced process")
      }
    )
    process.terminated = !replaced
    await windows.waitForDiscoveryRetries()
    #expect(attempts == 1)
    #expect(windows.application(by: process.pid) == nil)
  }

  @Test("retryDiscovery: a terminated process cannot suppress its replacement's retry")
  func retryDiscoveryATerminatedProcessCannotSuppressItsReplacementsRetry() async {
    let windows = Windows(workspace: Workspace(), focusedWindowID: nil)
    let old = Process(psn: .init(), pid: 42, name: "old")
    let replacement = Process(psn: .init(), pid: 42, name: "replacement")
    var retries = [String]()
    windows.retryDiscovery(for: old, resolveProcess: { old }, retry: { retries.append("old") })
    windows.retryDiscovery(
      for: replacement,
      resolveProcess: { replacement },
      retry: { retries.append("replacement") }
    )
    old.terminated = true
    windows.cancelDiscoveryRetry(for: old)
    await windows.waitForDiscoveryRetries()
    #expect(retries == ["replacement"])
  }

  @Test("addLostFrontSwitchedEvent/removeLostFrontSwitchedEvent: consumes once")
  func addLostFrontSwitchedEventRemoveLostFrontSwitchedEventConsumesOnce() {
    let windows = Windows(workspace: Workspace(), focusedWindowID: nil)
    let processID: pid_t = 42

    #expect(windows.removeLostFrontSwitchedEvent(for: processID) == false)

    windows.addLostFrontSwitchedEvent(for: processID)

    #expect(windows.removeLostFrontSwitchedEvent(for: processID))
    #expect(windows.removeLostFrontSwitchedEvent(for: processID) == false)
  }

  @Test("addLostFocusedEvent/removeLostFocusedEvent: tracks and consumes once")
  func addLostFocusedEventRemoveLostFocusedEventTracksAndConsumesOnce() {
    let windows = Windows(workspace: Workspace(), focusedWindowID: nil)
    let windowID: CGWindowID = 42

    #expect(windows.removeLostFocusedEvent(for: windowID) == false)

    windows.addLostFocusedEvent(for: windowID)

    #expect(windows.removeLostFocusedEvent(for: windowID))
    #expect(windows.removeLostFocusedEvent(for: windowID) == false)
  }
}
