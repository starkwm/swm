import Testing

@testable import SwmLib

@Suite("Signals")
struct SignalsTests {
  @Test("add: rejects duplicate labels")
  func addRejectsDuplicateLabels() throws {
    let signals = Signals()
    let first = try signal(label: "same", action: "one")
    let second = try signal(label: "same", action: "two")

    try signals.add(first)

    do {
      try signals.add(second)
      Issue.record("Expected duplicate label rejection")
    } catch let error as IPCCommandError {
      #expect(error.message == "signal label already exists: same")
      #expect(error.errorCode == .invalidRequest)
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  @Test("remove: removes by one-based index and label")
  func removeRemovesByIndexAndLabel() throws {
    let signals = Signals()

    try signals.add(signal(label: "first", action: "one"))
    try signals.add(signal(label: "second", action: "two"))
    try signals.add(signal(label: "third", action: "three"))

    try signals.remove(selector: "2")
    #expect(signals.list().map(\.signal.label) == ["first", "third"])

    try signals.remove(selector: "third")
    #expect(signals.list().map(\.signal.label) == ["first"])
  }

  private func signal(
    label: String?,
    action: String,
    app: String? = nil
  ) throws -> Signal {
    var arguments = [
      "event=window-focused",
      "action=\(action)",
    ]

    if let label {
      arguments.append("label=\(label)")
    }

    if let app {
      arguments.append("app=\(app)")
    }

    return try Signal.parseAdd(arguments: arguments)
  }
}
