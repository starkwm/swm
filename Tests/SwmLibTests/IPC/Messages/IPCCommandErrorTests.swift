import Testing

@testable import SwmLib

@Suite("IPCCommandError")
struct IPCCommandErrorTests {
  @Test("response: builds failure response")
  func responseBuildsFailureResponse() {
    let response = IPCCommandError.invalidRequest("bad request").response(id: "request-id")

    #expect(response.id == "request-id")
    #expect(response.ok == false)
    #expect(response.message == "bad request")
    #expect(response.errorCode == .invalidRequest)
  }

  @Test("catching: converts thrown command error")
  func catchingConvertsThrownCommandError() {
    let response = IPCCommandError.catching(id: "request-id") {
      throw IPCCommandError.unsupportedCommand("nope")
    }

    #expect(response.id == "request-id")
    #expect(response.ok == false)
    #expect(response.message == "nope")
    #expect(response.errorCode == .unsupportedCommand)
  }
}
