import Testing

@testable import SwmLib

@MainActor
@Suite("IPCCommandDispatcher")
struct IPCCommandDispatcherTests {
  @Test("dispatch: activates a Space without requiring a tracked active Space")
  func dispatchActivatesASpaceWithoutRequiringATrackedActiveSpace() async {
    let spaces = Spaces(activeSpaceID: nil)
    var selectedIndex: Int?
    let dispatcher = IPCCommandDispatcher(
      windows: Windows(workspace: Workspace(), focusedWindowID: nil),
      spaces: spaces,
      displays: Displays(),
      tiling: makeTestTiling(spaces: spaces),
      activateSpace: { selectedIndex = $0 }
    )

    let response = await dispatcher.dispatch(
      IPCRequest(id: "request-id", command: .spaceActivate(index: 2))
    )

    #expect(response.ok && response.message.isEmpty)
    #expect(response.id == "request-id")
    #expect(selectedIndex == 2)
  }

  @Test("dispatch: activation failures remain failures")
  func dispatchActivationFailuresRemainFailures() async {
    let spaces = Spaces(activeSpaceID: 42)
    let dispatcher = IPCCommandDispatcher(
      windows: Windows(workspace: Workspace(), focusedWindowID: nil),
      spaces: spaces,
      displays: Displays(),
      tiling: makeTestTiling(spaces: spaces),
      activateSpace: { _ in throw SpaceBridgeError.unavailable(.activation) }
    )

    let response = await dispatcher.dispatch(
      IPCRequest(id: "request-id", command: .spaceActivate(index: 1))
    )
    #expect(!response.ok)
    #expect(response.errorCode == .internalError)
    #expect(response.message == SpaceBridgeError.unavailable(.activation).description)
  }

  @Test("dispatch: activation rejects non-positive indexes", arguments: [0, -1])
  func dispatchActivationRejectsNonPositiveIndexes(index: Int) async {
    let spaces = Spaces(activeSpaceID: 42)
    let dispatcher = IPCCommandDispatcher(
      windows: Windows(workspace: Workspace(), focusedWindowID: nil),
      spaces: spaces,
      displays: Displays(),
      tiling: makeTestTiling(spaces: spaces),
      activateSpace: { _ in Issue.record("unexpected activation") }
    )

    let response = await dispatcher.dispatch(
      IPCRequest(id: "request-id", command: .spaceActivate(index: index))
    )
    #expect(response.errorCode == .invalidRequest)
  }
}
