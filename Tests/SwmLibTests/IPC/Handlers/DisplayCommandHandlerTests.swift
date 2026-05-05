import Foundation
import Testing

@testable import SwmLib

@Suite("DisplayCommandHandler")
struct DisplayCommandHandlerTests {
  @Test("dispatch: rejects previous focus target as unimplemented")
  func dispatchRejectsPreviousFocusTargetAsUnimplemented() {
    let manager = DisplayManager()
    let handler = DisplayCommandHandler(
      displayManager: manager,
      displays: { displays(focusedIndex: 1) }
    )

    let response = handler.dispatch(request(args: ["prev"]))

    #expect(response.ok == false)
    #expect(response.errorCode == .unsupportedCommand)
    #expect(response.message == "display focus is not implemented")
  }

  @Test("dispatch: rejects next focus target as unimplemented")
  func dispatchRejectsNextFocusTargetAsUnimplemented() {
    let manager = DisplayManager()
    let handler = DisplayCommandHandler(
      displayManager: manager,
      displays: { displays(focusedIndex: 1) }
    )

    let response = handler.dispatch(request(args: ["next"]))

    #expect(response.ok == false)
    #expect(response.errorCode == .unsupportedCommand)
    #expect(response.message == "display focus is not implemented")
  }

  @Test("dispatch: wraps previous focus target")
  func dispatchWrapsPreviousFocusTarget() {
    let manager = DisplayManager()
    let handler = DisplayCommandHandler(
      displayManager: manager,
      displays: { displays(focusedIndex: 0) }
    )

    let response = handler.dispatch(request(args: ["prev"]))

    #expect(response.ok == false)
    #expect(response.errorCode == .unsupportedCommand)
    #expect(response.message == "display focus is not implemented")
  }

  @Test("dispatch: wraps next focus target")
  func dispatchWrapsNextFocusTarget() {
    let manager = DisplayManager()
    let handler = DisplayCommandHandler(
      displayManager: manager,
      displays: { displays(focusedIndex: 2) }
    )

    let response = handler.dispatch(request(args: ["next"]))

    #expect(response.ok == false)
    #expect(response.errorCode == .unsupportedCommand)
    #expect(response.message == "display focus is not implemented")
  }

  @Test("dispatch: rejects indexed focus target as unimplemented")
  func dispatchRejectsIndexedFocusTargetAsUnimplemented() {
    let manager = DisplayManager()
    let handler = DisplayCommandHandler(
      displayManager: manager,
      displays: { displays(focusedIndex: 0) }
    )

    let response = handler.dispatch(request(args: ["2"]))

    #expect(response.ok == false)
    #expect(response.errorCode == .unsupportedCommand)
    #expect(response.message == "display focus is not implemented")
  }

  @Test("dispatch: rejects malformed focus arguments")
  func dispatchRejectsMalformedFocusArguments() {
    let manager = DisplayManager()
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
      DisplayCommandHandler(displayManager: DisplayManager(), displays: { [] })
        .dispatch(request(args: ["recent"])),
    ]

    #expect(responses.allSatisfy { !$0.ok && $0.errorCode == .invalidRequest })
  }

  @Test("dispatch: rejects unsupported display commands")
  func dispatchRejectsUnsupportedDisplayCommands() {
    let response = DisplayCommandHandler(displayManager: DisplayManager()).dispatch(
      IPCRequest(id: "request-id", domain: .display, command: "--unknown", args: [])
    )

    #expect(response.ok == false)
    #expect(response.errorCode == .unsupportedCommand)
    #expect(response.message == "unsupported display command: --unknown")
  }

  private func request(args: [String]) -> IPCRequest {
    IPCRequest(id: "request-id", domain: .display, command: "--focus", args: args)
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
