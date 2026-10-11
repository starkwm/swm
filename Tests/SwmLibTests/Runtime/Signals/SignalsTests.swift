import Foundation
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
  func removeRemovesByOneBasedIndexAndLabel() throws {
    let signals = Signals()

    try signals.add(signal(label: "first", action: "one"))
    try signals.add(signal(label: "second", action: "two"))
    try signals.add(signal(label: "third", action: "three"))

    try signals.remove(selector: "2")
    #expect(signals.list().map(\.signal.label) == ["first", "third"])

    try signals.remove(selector: "third")
    #expect(signals.list().map(\.signal.label) == ["first"])
  }

  @Test("hasSubscribers: follows event registrations and removal")
  func hasSubscribersFollowsEventRegistrationsAndRemoval() throws {
    let signals = Signals()
    #expect(!signals.hasSubscribers(for: .windowMoved))
    try signals.add(
      Signal.parseAdd(arguments: ["event=window-moved", "action=true", "label=move"])
    )
    #expect(signals.hasSubscribers(for: .windowMoved))
    #expect(!signals.hasSubscribers(for: .windowResized))
    try signals.remove(selector: "move")
    #expect(!signals.hasSubscribers(for: .windowMoved))
  }

  @Test("emit: filters parsed registrations and delivers their environment until removal")
  func emitFiltersParsedRegistrationsAndDeliversTheirEnvironmentUntilRemoval() throws {
    let recorder = SignalEmissionRecorder()
    let signals = Signals(executionQueue: SignalExecutionQueue(executor: recorder.execute))
    try signals.add(
      Signal.parseAdd(arguments: [
        "label=focus", "event=window-focused", "action=echo $SWM_WINDOW_ID",
        "app=^Safari$", "title!=Private", "active=yes",
      ])
    )
    let matching = SignalPayload(
      event: .windowFocused,
      app: "Safari",
      title: "Docs",
      active: true,
      environment: ["SWM_WINDOW_ID": "42"]
    )
    for payload in [
      SignalPayload(
        event: .windowFocused,
        app: "Terminal",
        title: "Docs",
        active: true,
        environment: [:]
      ),
      SignalPayload(
        event: .windowFocused,
        app: "Safari",
        title: "Private",
        active: true,
        environment: [:]
      ),
      SignalPayload(
        event: .windowFocused,
        app: "Safari",
        title: "Docs",
        active: false,
        environment: [:]
      ),
      SignalPayload(
        event: .windowMoved,
        app: "Safari",
        title: "Docs",
        active: true,
        environment: [:]
      ),
      SignalPayload(event: .windowFocused, app: nil, title: nil, active: nil, environment: [:]),
    ] { signals.emit(payload) }
    #expect(recorder.actions.isEmpty)
    signals.emit(matching)
    #expect(recorder.actions == ["echo $SWM_WINDOW_ID"])
    #expect(recorder.environments == [["SWM_WINDOW_ID": "42"]])
    try signals.remove(selector: "focus")
    signals.emit(matching)
    #expect(recorder.actions.count == 1)
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

private final class SignalEmissionRecorder: @unchecked Sendable {
  var actions: [String] { lock.withLock { recordedActions } }
  var environments: [[String: String]] { lock.withLock { recordedEnvironments } }
  private let lock = NSLock()
  private var recordedActions = [String]()
  private var recordedEnvironments = [[String: String]]()

  func execute(
    action: String,
    environment: [String: String],
    completion: @escaping @Sendable () -> Void
  ) {
    lock.withLock {
      recordedActions.append(action)
      recordedEnvironments.append(environment)
    }
    completion()
  }
}
