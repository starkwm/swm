import Carbon
import Testing

@testable import SwmLib

@Suite("RuntimeEventSignalMapper")
@MainActor
struct RuntimeEventSignalMapperTests {
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
  func payloadAfterHandlingLeavesApplicationLifecycleSignalsWithHandler() {
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

  @Test("payload after handling: maps display reconfiguration")
  func payloadAfterHandlingMapsDisplayReconfiguration() {
    let payload = mapper().payload(afterHandling: .display(.moved(42)))

    #expect(payload?.event == .displayMoved)
    #expect(payload?.environment["SWM_EVENT_DISPLAY_ID"] == "42")
  }

  @Test("payload before handling: ignores events that remain projectable")
  func payloadBeforeHandlingIgnoresEventsThatRemainProjectable() {
    let mapper = mapper()

    #expect(mapper.payload(beforeHandling: .window(.created(42, 100))) == nil)
    #expect(mapper.payload(beforeHandling: .space(.changed(Space(id: 10)))) == nil)
    #expect(mapper.payload(beforeHandling: .display(.changed)) == nil)
  }

  private func mapper() -> RuntimeEventSignalMapper {
    RuntimeEventSignalMapper(
      windowManager: Windows(workspace: Workspace()),
      spaceManager: Spaces(activeSpaceID: nil),
      displayManager: Displays()
    )
  }
}
