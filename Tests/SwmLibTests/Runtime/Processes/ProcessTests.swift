import AppKit
import Testing

@testable import SwmLib

@Suite("Process")
@MainActor
struct ProcessTests {
  @Test("resolveApplication: looks up an application that was unavailable at launch")
  func resolveApplicationLooksUpAnApplicationThatWasUnavailableAtLaunch() {
    let process = SwmLib.Process(psn: .init(), pid: 42, name: "-")
    var lookups = 0
    let lookup: (pid_t) -> NSRunningApplication? = { _ in
      lookups += 1
      return lookups == 1 ? nil : .current
    }

    #expect(process.resolveApplication(lookup: lookup) == nil)
    #expect(process.resolveApplication(lookup: lookup) == .current)
    #expect(process.application == .current)
    #expect(process.name == NSRunningApplication.current.localizedName ?? "-")
    #expect(process.resolveApplication(lookup: lookup) == .current)
    #expect(lookups == 2)
  }

  @Test("resolveApplication: does not resolve a terminated process")
  func resolveApplicationDoesNotResolveATerminatedProcess() {
    let process = SwmLib.Process(psn: .init(), pid: 42, name: "-", terminated: true)

    #expect(process.resolveApplication(lookup: { _ in .current }) == nil)
    #expect(process.application == nil)
  }
}
