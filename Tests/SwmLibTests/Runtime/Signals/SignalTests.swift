import Testing

@testable import SwmLib

@Suite("Signal")
struct SignalTests {
  @Test("parseAdd: preserves operators in values and inverts only text filters")
  func parseAddPreservesOperatorsInValuesAndInvertsOnlyTextFilters() throws {
    let signal = try Signal.parseAdd(arguments: [
      "event=window-focused", "action=test a != b && echo changed",
      "app=^a!=b=c$", "title!=^Settings$",
    ])
    #expect(signal.action == "test a != b && echo changed")
    #expect(signal.appFilter?.pattern == "^a!=b=c$")
    #expect(signal.appFilter?.matches("a!=b=c") == true)
    #expect(signal.titleFilter?.matches("Settings") == false)
    #expect(signal.titleFilter?.matches("Other") == true)
    for key in ["event", "action", "label", "active", "unknown"] {
      expectInvalid(
        arguments: ["event=window-focused", "action=true", "\(key)!=value"],
        message: "unsupported signal argument: \(key)!"
      )
    }
    for argument in ["=value", "title=", "title", "!=value"] {
      expectInvalid(
        arguments: ["event=window-focused", "action=true", argument],
        message: "invalid signal argument: \(argument)"
      )
    }
  }

  @Test("parseAdd: rejects missing event and action")
  func parseAddRejectsMissingEventAndAction() {
    expectInvalid(arguments: ["action=echo"], message: "missing signal event")
    expectInvalid(arguments: ["event=window-focused"], message: "missing signal action")
  }

  @Test("parseAdd: rejects unsupported events and arguments")
  func parseAddRejectsUnsupportedEventsAndArguments() {
    let error = #expect(throws: IPCCommandError.self) {
      try Signal.parseAdd(arguments: ["event=dock-did-restart", "action=echo"])
    }
    #expect(
      error?.message.hasPrefix("unsupported signal event: dock-did-restart; expected one of ")
        == true
    )
    #expect(error?.message.contains("window-focused") == true)
    expectInvalid(
      arguments: ["event=window-focused", "action=echo", "foo=bar"],
      message:
        "unsupported signal argument: foo; expected event, action, label, app, title, or active"
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
