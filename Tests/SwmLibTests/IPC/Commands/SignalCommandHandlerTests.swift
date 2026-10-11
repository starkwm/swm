import Foundation
import Testing

@testable import SwmLib

@Suite("SignalCommandHandler", .serialized)
struct SignalCommandHandlerTests {
  @Test(
    "dispatch: registers filters, lists JSON, and removes the registration",
    arguments: [false, true]
  )
  func dispatchRegistersFiltersListsJSONAndRemovesTheRegistration(filtered: Bool) throws {
    let handler = SignalCommandHandler()
    let label = "focused-\(UUID().uuidString)"
    defer { _ = handler.dispatch(request(command: "--remove", args: [label])) }
    let args =
      [
        "event=window-focused", "action=echo $SWM_WINDOW_ID", "label=\(label)",
      ] + (filtered ? ["app=Safari", "title!=Private", "active=yes"] : [])
    #expect(handler.dispatch(request(command: "--add", args: args)).ok)
    let duplicate = handler.dispatch(request(command: "--add", args: args))
    #expect(duplicate.errorCode == .invalidRequest)
    #expect(duplicate.message == "signal label already exists: \(label)")
    let list = handler.dispatch(request(command: "--list", args: []))
    #expect(list.ok)
    let entries = try #require(
      JSONSerialization.jsonObject(with: Data(list.message.utf8)) as? [[String: Any]]
    )
    let matching = entries.filter { $0["label"] as? String == label }
    #expect(matching.count == 1)
    let entry = try #require(matching.first)
    let index = try #require(entry["index"] as? Int)
    #expect(entry["event"] as? String == "window-focused")
    #expect(entry["action"] as? String == "echo $SWM_WINDOW_ID")
    if filtered {
      #expect(entry["app"] as? String == "Safari")
      #expect(entry["title"] as? String == "!Private")
      #expect(entry["active"] as? Bool == true)
    } else {
      #expect(entry["app"] is NSNull)
      #expect(entry["title"] is NSNull)
      #expect(entry["active"] is NSNull)
    }
    #expect(
      handler.dispatch(request(command: "--remove", args: [filtered ? String(index) : label])).ok
    )
    #expect(!Signals.shared.list().contains { $0.signal.label == label })
  }

  @Test("dispatch: rejects malformed remove and list arguments")
  func dispatchRejectsMalformedRemoveAndListArguments() {
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

  @Test("dispatch: signal rejects unsupported commands")
  func dispatchSignalRejectsUnsupportedCommands() {
    let response = SignalCommandHandler().dispatch(
      request(command: "add", args: [])
    )

    #expect(response.id == "request-id")
    #expect(response.ok == false)
    #expect(response.errorCode == .unsupportedCommand)
    #expect(response.message == "unsupported signal command: add")
  }

  private func request(command: String, args: [String]) -> IPCRequest {
    IPCRequest(id: "request-id", domain: .signal, command: command, args: args)
  }
}
