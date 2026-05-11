import Foundation
import Testing

@testable import SwmLib

@Suite("SignalCommandHandler")
struct SignalCommandHandlerTests {
  @Test("dispatch: adds and lists signals")
  func dispatchAddsAndListsSignals() {
    let handler = SignalCommandHandler()
    let label = "focused-\(UUID().uuidString)"

    let add = handler.dispatch(
      request(
        command: "--add",
        args: [
          "event=window-focused",
          "action=echo $SWM_WINDOW_ID",
          "label=\(label)",
          "app=Safari",
          "active=yes",
        ]
      )
    )
    let list = handler.dispatch(request(command: "--list", args: []))
    _ = handler.dispatch(request(command: "--remove", args: [label]))

    #expect(add.ok == true)
    #expect(add.message == "ok")
    #expect(list.ok == true)
    #expect(list.message.contains("\"event\":\"window-focused\""))
    #expect(list.message.contains("\"label\":\"\(label)\""))
  }

  @Test("dispatch: removes signals")
  func dispatchRemovesSignals() {
    let handler = SignalCommandHandler()
    let label = "focused-\(UUID().uuidString)"

    _ = handler.dispatch(
      request(command: "--add", args: ["event=window-focused", "action=echo", "label=\(label)"])
    )

    let remove = handler.dispatch(request(command: "--remove", args: [label]))

    #expect(remove.ok == true)
    #expect(remove.message == "ok")
  }

  @Test("dispatch: rejects malformed remove and list arguments")
  func dispatchRejectsMalformedArguments() {
    let handler = SignalCommandHandler()
    let remove = handler.dispatch(request(command: "--remove", args: []))
    let list = handler.dispatch(request(command: "--list", args: ["extra"]))

    #expect(remove.ok == false)
    #expect(remove.errorCode == .invalidRequest)
    #expect(remove.message == "invalid signal remove arguments")
    #expect(list.ok == false)
    #expect(list.errorCode == .invalidRequest)
    #expect(list.message == "invalid signal list arguments")
  }

  private func request(command: String, args: [String]) -> IPCRequest {
    IPCRequest(id: "request-id", domain: .signal, command: command, args: args)
  }
}
