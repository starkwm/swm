import Carbon
import Testing

@testable import SwmLib

@Suite("RuntimeEventSignalMapper")
@MainActor
struct RuntimeEventSignalMapperTests {
  @Test("payload before handling: ignores events that remain projectable")
  func payloadBeforeHandlingIgnoresEventsThatRemainProjectable() {
    let mapper = mapper()

    #expect(mapper.payload(beforeHandling: .window(.created(42, 100))) == nil)
    #expect(mapper.payload(beforeHandling: .space(.changed(Space(id: 10)))) == nil)
    #expect(mapper.payload(beforeHandling: .display(.changed)) == nil)
  }

  @Test("payload after handling: skips window events without subscribers")
  func payloadAfterHandlingSkipsWindowEventsWithoutSubscribers() {
    var observedEvents = Set<SignalEvent>()
    let mapper = RuntimeEventSignalMapper(
      windows: Windows(workspace: Workspace(), focusedWindowID: nil),
      spaces: Spaces(activeSpaceID: nil),
      displays: Displays(),
      hasSubscribers: { observedEvents.contains($0) }
    )
    #expect(mapper.payload(afterHandling: .window(.moved(42))) == nil)
    #expect(mapper.payload(afterHandling: .window(.resized(42))) == nil)

    observedEvents.insert(.windowMoved)
    let payload = mapper.payload(afterHandling: .window(.moved(42)))
    #expect(payload?.event == .windowMoved)
    #expect(payload?.environment["SWM_WINDOW_ID"] == "42")
    #expect(mapper.payload(afterHandling: .window(.resized(42))) == nil)
  }

  @Test("payload after handling: maps frontmost application")
  func payloadAfterHandlingMapsFrontmostApplication() {
    let process = Process(
      psn: ProcessSerialNumber(highLongOfPSN: 1, lowLongOfPSN: 2),
      pid: 42,
      name: "Example"
    )

    let payload = mapper().payload(afterHandling: .application(.frontSwitched(process)))

    #expect(payload?.event == .applicationFrontSwitched)
    #expect(payload?.app == "Example")
    #expect(payload?.active == true)
    #expect(payload?.environment["SWM_PROCESS_ID"] == "42")
  }

  @Test("payload after handling: leaves application lifecycle signals with their handler")
  func payloadAfterHandlingLeavesApplicationLifecycleSignalsWithTheirHandler() {
    let process = Process(
      psn: ProcessSerialNumber(highLongOfPSN: 1, lowLongOfPSN: 2),
      pid: 42,
      name: "Example"
    )
    let mapper = mapper()

    #expect(mapper.payload(afterHandling: .application(.launched(process))) == nil)
    #expect(mapper.payload(afterHandling: .application(.terminated(process))) == nil)
  }

  @Test("payload after handling: maps window IDs and focus state")
  func payloadAfterHandlingMapsWindowIDsAndFocusState() {
    let mapper = mapper()
    let created = mapper.payload(afterHandling: .window(.created(42, 100)))
    let focused = mapper.payload(afterHandling: .window(.focused(200)))

    #expect(created?.event == .windowCreated)
    #expect(created?.environment["SWM_WINDOW_ID"] == "100")
    #expect(focused?.event == .windowFocused)
    #expect(focused?.active == true)
    #expect(focused?.environment["SWM_WINDOW_ID"] == "200")
  }

  @Test(
    "payload after handling: maps display reconfiguration to parsed signal actions",
    arguments: [
      (DisplayEvent.added(42), SignalEvent.displayAdded),
      (.removed(42), .displayRemoved), (.moved(42), .displayMoved), (.resized(42), .displayResized),
    ]
  )
  func payloadAfterHandlingMapsDisplayReconfigurationToParsedSignalActions(
    event: DisplayEvent,
    expected: SignalEvent
  ) throws {
    let recorder = SignalEmissionRecorder()
    let signals = Signals(executionQueue: SignalExecutionQueue(executor: recorder.execute))
    try signals.add(Signal.parseAdd(arguments: ["event=\(expected.rawValue)", "action=record"]))
    let payload = try #require(mapper().payload(afterHandling: .display(event)))
    #expect(payload.event == expected)
    signals.emit(payload)
    #expect(recorder.actions == ["record"])
    #expect(recorder.environments.first?["SWM_EVENT_DISPLAY_ID"] == "42")
  }

  private func mapper() -> RuntimeEventSignalMapper {
    RuntimeEventSignalMapper(
      windows: Windows(workspace: Workspace(), focusedWindowID: nil),
      spaces: Spaces(activeSpaceID: nil),
      displays: Displays()
    )
  }
}
