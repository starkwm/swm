import AppKit
import Carbon
import Testing

@testable import SwmLib

@Suite("Workspace")
struct WorkspaceTests {
  @Test("isObservable returns true for regular applications")
  func isObservableReturnsTrueForRegularApplication() {
    let process = process(
      lowPSN: 1,
      application: testApplication(policy: .regular, finishedLaunching: true)
    )

    #expect(Workspace.shared.isObservable(process))
    #expect(process.policy == .regular)
  }

  @Test("isObservable returns false for non-regular applications")
  func isObservableReturnsFalseForNonRegularApplication() {
    let process = process(
      lowPSN: 2,
      application: testApplication(policy: .accessory, finishedLaunching: true)
    )

    #expect(!Workspace.shared.isObservable(process))
    #expect(process.policy == .accessory)
  }

  @Test("isObservable marks missing applications prohibited")
  func isObservableSetsProhibitedWhenApplicationIsMissing() {
    let process = process(lowPSN: 3, application: nil)

    #expect(!Workspace.shared.isObservable(process))
    #expect(process.policy == .prohibited)
  }

  @Test("isFinishedLaunching reads application state")
  func isFinishedLaunchingReadsApplicationState() {
    let launched = process(
      lowPSN: 4,
      application: testApplication(policy: .regular, finishedLaunching: true)
    )
    let missing = process(lowPSN: 5, application: nil)

    #expect(Workspace.shared.isFinishedLaunching(launched))
    #expect(!Workspace.shared.isFinishedLaunching(missing))
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

private func testApplication(
  policy: NSApplication.ActivationPolicy,
  finishedLaunching: Bool
) -> NSRunningApplication {
  TestRunningApplication(policy: policy, finishedLaunching: finishedLaunching)
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
