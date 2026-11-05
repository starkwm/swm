import Testing

@testable import SwmLib

@MainActor
@Suite("DisplayCommandHandler")
struct DisplayCommandHandlerTests {
  @Test("dispatch: display rejects unsupported commands")
  func dispatchDisplayRejectsUnsupportedCommands() {
    let response = handler().dispatch(request(command: "--label", args: []))

    #expect(response.id == "request-id")
    #expect(response.ok == false)
    #expect(response.errorCode == .unsupportedCommand)
    #expect(response.message == "unsupported display command: --label")
  }

  @Test("dispatch: focus rejects missing and extra targets", arguments: [[], ["1", "2"]])
  func dispatchFocusRejectsMissingAndExtraTargets(args: [String]) {
    let response = handler().dispatch(request(command: "--focus", args: args))

    #expect(response.ok == false)
    #expect(response.errorCode == .invalidRequest)
    #expect(response.message == "invalid display focus arguments")
  }

  @Test("dispatch: focus rejects unknown targets", arguments: ["previous", "0", "north", "nope"])
  func dispatchFocusRejectsUnknownTargets(target: String) {
    let response = handler().dispatch(request(command: "--focus", args: [target]))

    #expect(response.ok == false)
    #expect(response.errorCode == .invalidRequest)
    #expect(
      response.message == "invalid display focus value: \(target); expected \(DisplayTarget.form)"
    )
  }

  private func handler() -> DisplayCommandHandler {
    DisplayCommandHandler(
      windows: Windows(workspace: Workspace(), focusedWindowID: nil),
      displays: Displays()
    )
  }

  private func request(command: String, args: [String]) -> IPCRequest {
    IPCRequest(id: "request-id", domain: .display, command: command, args: args)
  }
}
