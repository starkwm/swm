import AppKit
import Carbon
import Testing

@testable import SwmLib

private func testApplication(
  policy: NSApplication.ActivationPolicy,
  finishedLaunching: Bool
) -> NSRunningApplication {
  TestRunningApplication(policy: policy, finishedLaunching: finishedLaunching)
}

@Suite("Workspace")
struct WorkspaceTests {
  @Test("isObservable: returns true for regular application")
  func isObservableReturnsTrueForRegularApplication() {
    let workspace = Workspace()
    let process = process(
      lowPSN: 1,
      application: testApplication(policy: .regular, finishedLaunching: true)
    )

    #expect(workspace.isObservable(process))
    #expect(process.policy == .regular)
  }

  @Test("isObservable: returns false for non-regular application")
  func isObservableReturnsFalseForNonRegularApplication() {
    let workspace = Workspace()
    let process = process(
      lowPSN: 2,
      application: testApplication(policy: .accessory, finishedLaunching: true)
    )

    #expect(!workspace.isObservable(process))
    #expect(process.policy == .accessory)
  }

  @Test("isObservable: marks missing applications prohibited")
  func isObservableMarksMissingApplicationsProhibited() {
    let workspace = Workspace()
    let process = process(lowPSN: 3, application: nil)

    #expect(!workspace.isObservable(process))
    #expect(process.policy == .prohibited)
  }

  @Test("isFinishedLaunching: reads application state")
  func isFinishedLaunchingReadsApplicationState() {
    let workspace = Workspace()
    let launched = process(
      lowPSN: 4,
      application: testApplication(policy: .regular, finishedLaunching: true)
    )
    let missing = process(lowPSN: 5, application: nil)

    #expect(workspace.isFinishedLaunching(launched))
    #expect(!workspace.isFinishedLaunching(missing))
  }

  private func process(
    lowPSN: UInt32,
    application: NSRunningApplication?
  ) -> SwmLib.Process {
    SwmLib.Process(
      psn: ProcessSerialNumber(highLongOfPSN: 0, lowLongOfPSN: lowPSN),
      pid: 1,
      name: "Test",
      application: application
    )
  }
}

private final class TestRunningApplication: NSRunningApplication, @unchecked Sendable {
  private let testPolicy: NSApplication.ActivationPolicy
  private let testFinishedLaunching: Bool

  init(policy: NSApplication.ActivationPolicy, finishedLaunching: Bool) {
    self.testPolicy = policy
    self.testFinishedLaunching = finishedLaunching
    super.init()
  }

  override var activationPolicy: NSApplication.ActivationPolicy {
    testPolicy
  }

  override var isFinishedLaunching: Bool {
    testFinishedLaunching
  }
}
