import Foundation
import Testing

@testable import SwmLib

@Suite("Signals")
struct SignalsTests {
  @Test("add/remove: numeric labels cannot collide with index selectors")
  func addRemoveNumericLabelsCannotCollideWithIndexSelectors() throws {
    let recorder = SignalEmissionRecorder()
    let signals = Signals(executionQueue: SignalExecutionQueue(executor: recorder.execute))
    for label in ["first", "second"] {
      try signals.add(
        Signal.parseAdd(arguments: [
          "event=window-focused", "action=test a != b && echo changed", "label=\(label)",
        ])
      )
    }
    let original = signals.list()
    for label in ["2", "0", "-1", "+2", "02"] {
      #expect(throws: IPCCommandError.self) {
        try signals.add(
          Signal.parseAdd(arguments: [
            "event=window-focused", "action=true", "label=\(label)",
          ])
        )
      }
      #expect(signals.list() == original)
    }
    #expect(recorder.actions.isEmpty)
    #expect(signals.list().first?.signal.action == "test a != b && echo changed")
    try signals.remove(selector: "2")
    #expect(signals.list().map { $0.signal.label } == ["first"])
    try signals.remove(selector: "first")
    #expect(signals.list().isEmpty)
  }

  @Test("removeAll: drops every registration so labels can be registered again")
  func removeAllDropsEveryRegistrationSoLabelsCanBeRegisteredAgain() throws {
    let signals = Signals()
    let signal = try Signal.parseAdd(arguments: ["event=window-moved", "action=true", "label=a"])
    try signals.add(signal)
    signals.removeAll()

    #expect(signals.list().isEmpty)
    #expect(!signals.hasSubscribers(for: .windowMoved))
    try signals.add(signal)
    #expect(signals.list().count == 1)
  }

  @Test("hasSubscribers: follows indexed and labeled removal")
  func hasSubscribersFollowsIndexedAndLabeledRemoval() throws {
    let signals = Signals()
    #expect(!signals.hasSubscribers(for: .windowMoved))
    for (label, event) in [
      ("first", "window-moved"), ("second", "window-resized"), ("third", "window-moved"),
    ] {
      try signals.add(
        Signal.parseAdd(arguments: ["event=\(event)", "action=true", "label=\(label)"])
      )
    }
    try signals.remove(selector: "2")
    #expect(!signals.hasSubscribers(for: .windowResized))
    try signals.remove(selector: "third")
    #expect(signals.hasSubscribers(for: .windowMoved))
    try signals.remove(selector: "first")
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
}
