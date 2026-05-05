import Testing

@testable import SwmLib

@Suite("IPCCommandDispatcher")
struct IPCCommandDispatcherTests {
  @Test("dispatch: routes requests by domain")
  func dispatchRoutesRequestsByDomain() {
    let dispatcher = IPCCommandDispatcher()
    let cases: [(domain: MessageDomain, message: String)] = [
      (.query, "unsupported query command: --unknown"),
      (.space, "unsupported space command: --unknown"),
      (.config, "unsupported config command: --unknown"),
      (.display, "unsupported display command: --unknown"),
      (.window, "unsupported window command: --unknown"),
    ]

    for testCase in cases {
      let response = dispatcher.dispatch(
        IPCRequest(
          id: "\(testCase.domain.rawValue)-request",
          domain: testCase.domain,
          command: "--unknown",
          args: []
        )
      )

      #expect(response.id == "\(testCase.domain.rawValue)-request")
      #expect(response.ok == false)
      #expect(response.errorCode == .unsupportedCommand)
      #expect(response.message == testCase.message)
    }
  }
}
