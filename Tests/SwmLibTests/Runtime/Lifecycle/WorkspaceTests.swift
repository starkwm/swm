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

  @Test(
    "KVO callbacks revalidate registration after cancellation or termination",
    arguments: ["cancel", "restart", "terminate", "late", "deliver"]
  )
  func queuedCallbacks(action: String) async throws {
    var launched = [pid_t]()
    let workspace = Workspace { event in
      if case .application(.launched(let process)) = event { launched.append(process.pid) }
    }
    let application = ObservationRecordingApplication()
    let process = makeProcess(application: application)
    workspace.observeFinishedLaunching(process)
    let context = try #require(application.contexts["finishedLaunching"])
    if action == "late" {
      workspace.unobserveFinishedLaunching(process)
      workspace.observeFinishedLaunching(process)
    }
    workspace.observeValue(
      forKeyPath: "finishedLaunching",
      of: nil,
      change: [.newKey: true],
      context: context
    )
    switch action {
    case "cancel": workspace.unobserveFinishedLaunching(process)
    case "restart":
      workspace.unobserveFinishedLaunching(process)
      workspace.observeFinishedLaunching(process)
    case "terminate": process.terminated = true
    default: break
    }
    await withCheckedContinuation { continuation in
      DispatchQueue.main.async { continuation.resume() }
    }
    #expect(launched == (action == "deliver" ? [42] : []))
    workspace.unobserveFinishedLaunching(process)
  }

  @Test("KVO accepts background delivery without accessing mutable process state off actor")
  func backgroundCallback() async throws {
    var launched = [pid_t]()
    let workspace = Workspace { event in
      if case .application(.launched(let process)) = event { launched.append(process.pid) }
    }
    let application = ObservationRecordingApplication()
    let process = makeProcess(application: application)
    workspace.observeActivationPolicy(process)
    let context = try #require(application.contexts["activationPolicy"])
    let address = UInt(bitPattern: context)
    await Task.detached {
      workspace.observeValue(
        forKeyPath: "activationPolicy",
        of: nil,
        change: [.newKey: NSApplication.ActivationPolicy.regular.rawValue],
        context: UnsafeMutableRawPointer(bitPattern: address)
      )
    }.value
    await withCheckedContinuation { continuation in
      DispatchQueue.main.async { continuation.resume() }
    }
    #expect(launched == [42])
    #expect(application.removedKeyPaths == ["activationPolicy"])
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
  var contexts = [String: UnsafeMutableRawPointer]()
  var addedKeyPaths = [String]()
  var removedKeyPaths = [String]()

  override func addObserver(
    _ observer: NSObject,
    forKeyPath keyPath: String,
    options: NSKeyValueObservingOptions = [],
    context: UnsafeMutableRawPointer?
  ) {
    contexts[keyPath] = context
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
