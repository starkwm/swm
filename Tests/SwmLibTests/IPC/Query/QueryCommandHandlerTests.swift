import Testing

@testable import SwmLib

@Suite("QueryCommandHandler")
struct QueryCommandHandlerTests {
  @Test("dispatch: returns query JSON arrays")
  func dispatchReturnsQueryJSONArrays() {
    let dispatcher = IPCCommandDispatcher()

    for command in ["--displays", "--windows", "--spaces"] {
      let request = IPCRequest(
        id: "request-id",
        domain: .query,
        command: command,
        args: []
      )

      let response = dispatcher.dispatch(request)

      #expect(response.id == "request-id")
      #expect(response.ok)
      #expect(response.errorCode == nil)
      #expect(response.message.hasPrefix("["))
      #expect(response.message.hasSuffix("]"))
    }
  }

  @Test("dispatch: returns unsupported query command failure")
  func dispatchReturnsUnsupportedQueryCommandFailure() {
    let dispatcher = IPCCommandDispatcher()
    let request = IPCRequest(
      id: "request-id",
      domain: .query,
      command: "--unknown",
      args: []
    )

    let response = dispatcher.dispatch(request)

    #expect(response.id == "request-id")
    #expect(response.ok == false)
    #expect(response.errorCode == .unsupportedCommand)
    #expect(response.message == "unsupported query command: --unknown")
  }

  @Test("response: encodes singular misses as null")
  func responseEncodesSingularMissesAsNull() throws {
    let response = try QueryCommandHandler().response(
      id: "request-id",
      result: QueryResult<QueryWindow>.one(nil)
    )

    #expect(response.ok)
    #expect(response.message == "null")
  }
}
