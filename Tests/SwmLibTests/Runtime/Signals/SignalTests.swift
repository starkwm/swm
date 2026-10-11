import Testing

@testable import SwmLib

@Suite("Signal")
struct SignalTests {
  @Test("parseAdd: rejects missing event and action")
  func parseAddRejectsMissingEventAndAction() {
    expectInvalid(arguments: ["action=echo"], message: "missing signal event")
    expectInvalid(arguments: ["event=window-focused"], message: "missing signal action")
  }

  @Test("parseAdd: rejects unsupported events and arguments")
  func parseAddRejectsUnsupportedEventsAndArguments() {
    expectInvalid(
      arguments: ["event=dock-did-restart", "action=echo"],
      message: "unsupported signal event: dock-did-restart"
    )
    expectInvalid(
      arguments: ["event=window-focused", "action=echo", "foo=bar"],
      message: "unsupported signal argument: foo"
    )
  }

  @Test("parseAdd: rejects invalid regex and unsupported active filter")
  func parseAddRejectsInvalidRegexAndUnsupportedActiveFilter() {
    expectInvalid(
      arguments: ["event=window-focused", "action=echo", "app=["],
      message: "invalid signal regex: ["
    )
    expectInvalid(
      arguments: ["event=space-changed", "action=echo", "active=yes"],
      message: "signal event does not support active filter: space-changed"
    )
  }

  @Test("parseAdd: rejects active filter for display events")
  func parseAddRejectsActiveFilterForDisplayEvents() {
    let events: [SignalEvent] = [
      .displayChanged,
      .displayAdded,
      .displayRemoved,
      .displayMoved,
      .displayResized,
    ]

    for event in events {
      expectInvalid(
        arguments: ["event=\(event.rawValue)", "action=echo", "active=yes"],
        message: "signal event does not support active filter: \(event.rawValue)"
      )
    }
  }

  private func expectInvalid(arguments: [String], message: String) {
    do {
      _ = try Signal.parseAdd(arguments: arguments)
      Issue.record("Expected invalid signal arguments")
    } catch let error as IPCCommandError {
      #expect(error.message == message)
      #expect(error.errorCode == .invalidRequest)
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }
}
