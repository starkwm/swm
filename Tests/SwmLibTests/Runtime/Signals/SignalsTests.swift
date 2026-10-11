import Foundation
import Testing

@testable import SwmLib

@Suite("Signals")
struct SignalsTests {
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
