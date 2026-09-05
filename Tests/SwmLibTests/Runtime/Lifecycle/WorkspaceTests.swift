import AppKit
import Testing

@testable import SwmLib

@Suite("Workspace")
@MainActor
struct WorkspaceTests {
  @Test("Launch retries register each readiness observer only once")
  func repeatedObservation() {
    let workspace = Workspace()
    let application = ObservationRecordingApplication()
    let process = makeProcess(application: application)

    for _ in 0..<3 {
      workspace.observeFinishedLaunching(process)
      workspace.observeActivationPolicy(process)
    }

    #expect(application.addedKeyPaths == ["finishedLaunching", "activationPolicy"])

    workspace.unobserveFinishedLaunching(process)
    workspace.unobserveActivationPolicy(process)
    workspace.unobserveFinishedLaunching(process)
    workspace.unobserveActivationPolicy(process)

    #expect(application.removedKeyPaths == application.addedKeyPaths)
  }

  @Test("Observation can restart after cleanup")
  func observeAfterCleanup() {
    let workspace = Workspace()
    let application = ObservationRecordingApplication()
    let process = makeProcess(application: application)

    for _ in 0..<2 {
      workspace.observeFinishedLaunching(process)
      workspace.observeActivationPolicy(process)
      workspace.unobserveFinishedLaunching(process)
      workspace.unobserveActivationPolicy(process)
    }

    #expect(
      application.addedKeyPaths == [
        "finishedLaunching", "activationPolicy", "finishedLaunching", "activationPolicy",
      ]
    )
    #expect(application.removedKeyPaths == application.addedKeyPaths)
  }

  @Test("Cleanup uses the retained application after the process loses it")
  func cleanupAfterApplicationLoss() {
    let workspace = Workspace()
    let application = ObservationRecordingApplication()
    let process = makeProcess(application: application)

    workspace.observeFinishedLaunching(process)
    workspace.observeActivationPolicy(process)
    process.application = nil
    workspace.unobserveFinishedLaunching(process)
    workspace.unobserveActivationPolicy(process)

    #expect(application.removedKeyPaths == ["finishedLaunching", "activationPolicy"])
  }

  private func makeProcess(application: NSRunningApplication) -> SwmLib.Process {
    SwmLib.Process(
      psn: ProcessSerialNumber(highLongOfPSN: 0, lowLongOfPSN: 1),
      pid: 42,
      name: "Example",
      application: application
    )
  }
}

private final class ObservationRecordingApplication: NSRunningApplication {
  var addedKeyPaths = [String]()
  var removedKeyPaths = [String]()

  override func addObserver(
    _ observer: NSObject,
    forKeyPath keyPath: String,
    options: NSKeyValueObservingOptions = [],
    context: UnsafeMutableRawPointer?
  ) {
    addedKeyPaths.append(keyPath)
  }

  override func removeObserver(
    _ observer: NSObject,
    forKeyPath keyPath: String,
    context: UnsafeMutableRawPointer?
  ) {
    removedKeyPaths.append(keyPath)
  }
}

extension ObservationRecordingApplication: @unchecked Sendable {}
