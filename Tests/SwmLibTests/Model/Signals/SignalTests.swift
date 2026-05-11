import Testing

@testable import SwmLib

@Suite("Signal")
struct SignalTests {
  @Test("parseAdd: accepts full signal arguments")
  func parseAddAcceptsFullSignalArguments() throws {
    let signal = try Signal.parseAdd(
      arguments: [
        "event=window-focused",
        "action=echo $SWM_WINDOW_ID",
        "label=focus-log",
        "app=Safari",
        "title!=Private",
        "active=yes",
      ]
    )

    #expect(signal.event == .windowFocused)
    #expect(signal.action == "echo $SWM_WINDOW_ID")
    #expect(signal.label == "focus-log")
    #expect(signal.appFilter?.pattern == "Safari")
    #expect(signal.appFilter?.inverted == false)
    #expect(signal.titleFilter?.pattern == "Private")
    #expect(signal.titleFilter?.inverted == true)
    #expect(signal.active == true)
  }

  @Test("parseAdd: rejects missing event and action")
  func parseAddRejectsMissingRequiredArguments() {
    expectInvalid(arguments: ["action=echo"], message: "missing signal event")
    expectInvalid(arguments: ["event=window-focused"], message: "missing signal action")
  }

  @Test("parseAdd: rejects unsupported events and arguments")
  func parseAddRejectsUnsupportedValues() {
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
  func parseAddRejectsInvalidFilterArguments() {
    expectInvalid(
      arguments: ["event=window-focused", "action=echo", "app=["],
      message: "invalid signal regex: ["
    )
    expectInvalid(
      arguments: ["event=space-changed", "action=echo", "active=yes"],
      message: "signal event does not support active filter: space-changed"
    )
  }

  @Test("matches: applies regex, inversion, and active filters")
  func matchesAppliesFilters() throws {
    let signal = try Signal.parseAdd(
      arguments: [
        "event=window-focused",
        "action=echo",
        "app=Safari",
        "title!=Private",
        "active=yes",
      ]
    )

    #expect(
      signal.matches(
        payload(app: "Safari", title: "Docs", active: true)
      )
    )
    #expect(!signal.matches(payload(app: "Terminal", title: "Docs", active: true)))
    #expect(!signal.matches(payload(app: "Safari", title: "Private", active: true)))
    #expect(!signal.matches(payload(app: "Safari", title: "Docs", active: false)))
  }

  private func payload(app: String?, title: String?, active: Bool?) -> SignalPayload {
    SignalPayload(
      event: .windowFocused,
      app: app,
      title: title,
      active: active,
      environment: ["SWM_WINDOW_ID": "42"]
    )
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
