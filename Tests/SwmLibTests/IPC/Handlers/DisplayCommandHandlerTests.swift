import Foundation
import Testing

@testable import SwmLib

@Suite("DisplayCommandHandler")
struct DisplayCommandHandlerTests {
  @Test("dispatch: rejects recent focus target as unimplemented")
  func dispatchRejectsRecentFocusTargetAsUnimplemented() {
    let manager = displayManager(activeDisplayIDs: ["display-0", "display-1"])
    manager.activeDisplayDidChange()
    let handler = DisplayCommandHandler(displayManager: manager, displays: { [] })

    let response = handler.dispatch(request(args: ["recent"]))

    #expect(response.ok == false)
    #expect(response.errorCode == .unsupportedCommand)
    #expect(response.message == "display focus is not implemented")
  }

  @Test("dispatch: rejects previous focus target as unimplemented")
  func dispatchRejectsPreviousFocusTargetAsUnimplemented() {
    let manager = displayManager()
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
    let manager = displayManager()
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
    let manager = displayManager()
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
    let manager = displayManager()
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
    let manager = displayManager()
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
