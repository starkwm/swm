import Testing

@testable import SwmLib

@Suite("SignalManager")
struct SignalManagerTests {
  @Test("add: rejects duplicate labels")
  func addRejectsDuplicateLabels() throws {
    let manager = SignalManager()
    let first = try signal(label: "same", action: "one")
    let second = try signal(label: "same", action: "two")

    try manager.add(first)

    do {
      try manager.add(second)
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
    let manager = SignalManager()

    try manager.add(signal(label: "first", action: "one"))
    try manager.add(signal(label: "second", action: "two"))
    try manager.add(signal(label: "third", action: "three"))

    try manager.remove(selector: "2")
    #expect(manager.list().map(\.signal.label) == ["first", "third"])

    try manager.remove(selector: "third")
    #expect(manager.list().map(\.signal.label) == ["first"])
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
