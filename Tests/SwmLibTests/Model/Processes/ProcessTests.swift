import Carbon
import Testing

@testable import SwmLib

@Suite("Process")
struct ProcessTests {
  @Test("explicit initializer sets properties")
  func explicitInitializerSetsProperties() {
    let psn = ProcessSerialNumber(highLongOfPSN: 1, lowLongOfPSN: 2)
    let process = Process(psn: psn, pid: 42, name: "Example")

    #expect(process.psn.highLongOfPSN == 1)
    #expect(process.psn.lowLongOfPSN == 2)
    #expect(process.pid == 42)
    #expect(process.name == "Example")
    #expect(process.terminated == false)
    #expect(process.application == nil)
    #expect(process.policy == nil)
  }

  @Test("description includes pid and name")
  func descriptionIncludesPIDAndName() {
    let psn = ProcessSerialNumber(highLongOfPSN: 1, lowLongOfPSN: 2)
    let process = Process(psn: psn, pid: 42, name: "Example")

    #expect(process.description == "<Process pid: 42, name: Example>")
  }
}
