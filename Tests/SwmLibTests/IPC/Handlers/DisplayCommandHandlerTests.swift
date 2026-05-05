import Foundation
import Testing

@testable import SwmLib

@Suite("DisplayCommandHandler")
struct DisplayCommandHandlerTests {
  @Test("dispatch: accepts recent focus target")
  func dispatchAcceptsRecentFocusTarget() {
    let manager = displayManager(activeDisplayIDs: ["display-0", "display-1"])
    manager.activeDisplayDidChange()
    let handler = DisplayCommandHandler(displayManager: manager, displays: { [] })

    let response = handler.dispatch(request(args: ["recent"]))

    #expect(response.ok)
    #expect(response.message == "focused display: display-0")
    #expect(
      manager.lastFocusDisplayRequest
        == FocusDisplayRequest(
          id: "display-0",
          index: nil,
          source: "recent"
        )
    )
  }

  @Test("dispatch: accepts previous focus target")
  func dispatchAcceptsPreviousFocusTarget() {
    let manager = displayManager()
    let handler = DisplayCommandHandler(
      displayManager: manager,
      displays: { displays(focusedIndex: 1) }
    )

    let response = handler.dispatch(request(args: ["prev"]))

    #expect(response.ok)
    #expect(response.message == "focused display: display-0")
    #expect(
      manager.lastFocusDisplayRequest
        == FocusDisplayRequest(
          id: "display-0",
          index: 0,
          source: "prev"
        )
    )
  }

  @Test("dispatch: accepts next focus target")
  func dispatchAcceptsNextFocusTarget() {
    let manager = displayManager()
    let handler = DisplayCommandHandler(
      displayManager: manager,
      displays: { displays(focusedIndex: 1) }
    )

    let response = handler.dispatch(request(args: ["next"]))

    #expect(response.ok)
    #expect(response.message == "focused display: display-2")
    #expect(
      manager.lastFocusDisplayRequest
        == FocusDisplayRequest(
          id: "display-2",
          index: 2,
          source: "next"
        )
    )
  }

  @Test("dispatch: wraps previous focus target")
  func dispatchWrapsPreviousFocusTarget() {
    let manager = displayManager()
    let handler = DisplayCommandHandler(
      displayManager: manager,
      displays: { displays(focusedIndex: 0) }
    )

    let response = handler.dispatch(request(args: ["prev"]))

    #expect(response.ok)
    #expect(
      manager.lastFocusDisplayRequest
        == FocusDisplayRequest(
          id: "display-2",
          index: 2,
          source: "prev"
        )
    )
  }

  @Test("dispatch: wraps next focus target")
  func dispatchWrapsNextFocusTarget() {
    let manager = displayManager()
    let handler = DisplayCommandHandler(
      displayManager: manager,
      displays: { displays(focusedIndex: 2) }
    )

    let response = handler.dispatch(request(args: ["next"]))

    #expect(response.ok)
    #expect(
      manager.lastFocusDisplayRequest
        == FocusDisplayRequest(
          id: "display-0",
          index: 0,
          source: "next"
        )
    )
  }

  @Test("dispatch: accepts indexed focus target")
  func dispatchAcceptsIndexedFocusTarget() {
    let manager = displayManager()
    let handler = DisplayCommandHandler(
      displayManager: manager,
      displays: { displays(focusedIndex: 0) }
    )

    let response = handler.dispatch(request(args: ["2"]))

    #expect(response.ok)
    #expect(response.message == "focused display: display-2")
    #expect(
      manager.lastFocusDisplayRequest
        == FocusDisplayRequest(
          id: "display-2",
          index: 2,
          source: "2"
        )
    )
  }

  @Test("dispatch: rejects malformed focus arguments")
  func dispatchRejectsMalformedFocusArguments() {
    let manager = displayManager()
    let handler = DisplayCommandHandler(
      displayManager: manager,
      displays: { displays(focusedIndex: 0) }
    )

    let responses = [
      handler.dispatch(request(args: [])),
      handler.dispatch(request(args: ["next", "extra"])),
      handler.dispatch(request(args: ["unknown"])),
      handler.dispatch(request(args: ["10"])),
      DisplayCommandHandler(displayManager: manager, displays: { [] })
        .dispatch(request(args: ["next"])),
      DisplayCommandHandler(displayManager: displayManager(), displays: { [] })
        .dispatch(request(args: ["recent"])),
    ]

    #expect(responses.allSatisfy { !$0.ok && $0.errorCode == .invalidRequest })
  }

  @Test("dispatch: rejects unsupported display commands")
  func dispatchRejectsUnsupportedDisplayCommands() {
    let response = DisplayCommandHandler(displayManager: displayManager()).dispatch(
      IPCRequest(id: "request-id", domain: .display, command: "--unknown", args: [])
    )

    #expect(response.ok == false)
    #expect(response.errorCode == .unsupportedCommand)
    #expect(response.message == "unsupported display command: --unknown")
  }

  private func request(args: [String]) -> IPCRequest {
    IPCRequest(id: "request-id", domain: .display, command: "--focus", args: args)
  }

  private func displayManager(activeDisplayIDs: [String?] = [nil]) -> DisplayManager {
    let resolver = ActiveDisplayIDSequence(activeDisplayIDs)
    return DisplayManager(activeDisplayIDResolver: resolver.next)
  }

  private func displays(focusedIndex: Int?) -> [DisplaySerializer] {
    (0..<3).map { index in
      DisplaySerializer(
        id: "display-\(index)",
        uuid: "display-\(index)",
        index: index,
        frame: FrameSerializer(.zero),
        spaces: [],
        hasFocus: index == focusedIndex
      )
    }
  }
}

private final class ActiveDisplayIDSequence: @unchecked Sendable {
  private var values: [String?]

  init(_ values: [String?]) {
    self.values = values
  }

  func next() -> String? {
    guard !values.isEmpty else { return nil }

    return values.removeFirst()
  }
}
