import Foundation
import Testing

@testable import SwmLib

@MainActor
@Suite("SignalCommandHandler", .serialized)
struct SignalCommandHandlerTests {
  @Test(
    "dispatch: registers filters, lists JSON, and removes the registration",
    arguments: [false, true]
  )
  func dispatchRegistersFiltersListsJSONAndRemovesTheRegistration(filtered: Bool) throws {
    let handler = SignalCommandHandler()
    let label = "focused-\(UUID().uuidString)"
    func send(_ command: IPCCommand.Signal) -> IPCResponse {
      handler.dispatch(IPCRequest(id: "request-id", command: .signal(command)), command: command)
    }
    defer { _ = send(.remove(label)) }
    let args =
      [
        "event=window-focused", "action=echo $SWM_WINDOW_ID", "label=\(label)",
      ] + (filtered ? ["app=Safari", "title!=Private", "active=on"] : [])
    #expect(send(.add(args)).ok)
    let duplicate = send(.add(args))
    #expect(duplicate.errorCode == .invalidRequest)
    #expect(duplicate.message == "signal label already exists: \(label)")
    let list = send(.list)
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
    #expect(send(.remove(filtered ? String(index) : label)).ok)
    #expect(!Signals.shared.list().contains { $0.signal.label == label })
  }
}
