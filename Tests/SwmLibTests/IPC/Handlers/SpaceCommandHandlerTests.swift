import Foundation
import Testing

@testable import SwmLib

@Suite("SpaceCommandHandler")
struct SpaceCommandHandlerTests {
  @Test("dispatch: accepts toggle commands")
  func dispatchAcceptsToggleCommands() throws {
    let manager = SpaceManager(activeSpaceIDResolver: { nil })
    let handler = SpaceCommandHandler(spaceManager: manager, activeSpaceID: { 42 })

    let padding = handler.dispatch(request(command: "--toggle", args: ["padding"]))
    let gap = handler.dispatch(request(command: "--toggle", args: ["gap"]))

    #expect(padding.ok)
    #expect(gap.ok)
    #expect(try jsonObject(gap.message)["gap-enabled"] as? Bool == false)
    #expect(manager.settings(for: 42).paddingEnabled == false)
    #expect(manager.settings(for: 42).gapEnabled == false)
  }

  @Test("dispatch: accepts padding commands")
  func dispatchAcceptsPaddingCommands() throws {
    let manager = SpaceManager(activeSpaceIDResolver: { nil })
    let handler = SpaceCommandHandler(spaceManager: manager, activeSpaceID: { 42 })

    let absolute = handler.dispatch(request(command: "--padding", args: ["abs:20:20:20:20"]))
    let relative = handler.dispatch(request(command: "--padding", args: ["rel:10:0:-5:-5"]))

    #expect(absolute.ok)
    #expect(relative.ok)
    let object = try jsonObject(relative.message)
    let padding = try #require(object["padding"] as? [String: Int])

    #expect(object["id"] as? Int == 42)
    #expect(object["padding-enabled"] as? Bool == true)
    #expect(padding["top"] == 30)
    #expect(padding["bottom"] == 20)
    #expect(padding["left"] == 15)
    #expect(padding["right"] == 15)
    #expect(
      manager.settings(for: 42).padding == SpacePadding(top: 30, bottom: 20, left: 15, right: 15)
    )
  }

  @Test("dispatch: accepts gap commands")
  func dispatchAcceptsGapCommands() throws {
    let manager = SpaceManager(activeSpaceIDResolver: { nil })
    let handler = SpaceCommandHandler(spaceManager: manager, activeSpaceID: { 42 })

    let absolute = handler.dispatch(request(command: "--gap", args: ["abs:0"]))
    let relative = handler.dispatch(request(command: "--gap", args: ["rel:10"]))

    #expect(absolute.ok)
    #expect(relative.ok)
    let object = try jsonObject(relative.message)

    #expect(object["id"] as? Int == 42)
    #expect(object["gap-enabled"] as? Bool == true)
    #expect(object["gap"] as? Int == 10)
    #expect(manager.settings(for: 42).gap == 10)
  }

  @Test("dispatch: accepts recent focus target")
  func dispatchAcceptsRecentFocusTarget() {
    let manager = spaceManager(activeSpaceIDs: [1, 2])
    manager.activeSpaceDidChange()
    let handler = SpaceCommandHandler(
      spaceManager: manager,
      activeSpaceID: { 2 },
      spaces: { [] }
    )

    let response = handler.dispatch(request(command: "--focus", args: ["recent"]))

    #expect(response.ok)
    #expect(response.message == "focused space: 1")
    #expect(
      manager.lastFocusSpaceRequest == FocusSpaceRequest(id: 1, index: nil, source: "recent")
    )
  }

  @Test("dispatch: accepts previous focus target")
  func dispatchAcceptsPreviousFocusTarget() {
    let manager = spaceManager()
    let handler = SpaceCommandHandler(
      spaceManager: manager,
      activeSpaceID: { 2 },
      spaces: { spaces(focusedIndex: 1) }
    )

    let response = handler.dispatch(request(command: "--focus", args: ["prev"]))

    #expect(response.ok)
    #expect(response.message == "focused space: 100")
    #expect(
      manager.lastFocusSpaceRequest == FocusSpaceRequest(id: 100, index: 0, source: "prev")
    )
  }

  @Test("dispatch: accepts next focus target")
  func dispatchAcceptsNextFocusTarget() {
    let manager = spaceManager()
    let handler = SpaceCommandHandler(
      spaceManager: manager,
      activeSpaceID: { 2 },
      spaces: { spaces(focusedIndex: 1) }
    )

    let response = handler.dispatch(request(command: "--focus", args: ["next"]))

    #expect(response.ok)
    #expect(response.message == "focused space: 102")
    #expect(
      manager.lastFocusSpaceRequest == FocusSpaceRequest(id: 102, index: 2, source: "next")
    )
  }

  @Test("dispatch: wraps previous focus target")
  func dispatchWrapsPreviousFocusTarget() {
    let manager = spaceManager()
    let handler = SpaceCommandHandler(
      spaceManager: manager,
      activeSpaceID: { 2 },
      spaces: { spaces(focusedIndex: 0) }
    )

    let response = handler.dispatch(request(command: "--focus", args: ["prev"]))

    #expect(response.ok)
    #expect(
      manager.lastFocusSpaceRequest == FocusSpaceRequest(id: 102, index: 2, source: "prev")
    )
  }

  @Test("dispatch: wraps next focus target")
  func dispatchWrapsNextFocusTarget() {
    let manager = spaceManager()
    let handler = SpaceCommandHandler(
      spaceManager: manager,
      activeSpaceID: { 2 },
      spaces: { spaces(focusedIndex: 2) }
    )

    let response = handler.dispatch(request(command: "--focus", args: ["next"]))

    #expect(response.ok)
    #expect(
      manager.lastFocusSpaceRequest == FocusSpaceRequest(id: 100, index: 0, source: "next")
    )
  }

  @Test("dispatch: accepts indexed focus target")
  func dispatchAcceptsIndexedFocusTarget() {
    let manager = spaceManager()
    let handler = SpaceCommandHandler(
      spaceManager: manager,
      activeSpaceID: { 2 },
      spaces: { spaces(focusedIndex: 0) }
    )

    let response = handler.dispatch(request(command: "--focus", args: ["2"]))

    #expect(response.ok)
    #expect(response.message == "focused space: 102")
    #expect(
      manager.lastFocusSpaceRequest == FocusSpaceRequest(id: 102, index: 2, source: "2")
    )
  }

  @Test("dispatch: rejects malformed arguments")
  func dispatchRejectsMalformedArguments() {
    let handler = SpaceCommandHandler(
      spaceManager: SpaceManager(activeSpaceIDResolver: { nil }),
      activeSpaceID: { 42 }
    )

    let responses = [
      handler.dispatch(request(command: "--toggle", args: [])),
      handler.dispatch(request(command: "--toggle", args: ["unknown"])),
      handler.dispatch(request(command: "--padding", args: ["abs:1:2:3"])),
      handler.dispatch(request(command: "--padding", args: ["rel:1:2:x:4"])),
      handler.dispatch(request(command: "--gap", args: ["abs"])),
      handler.dispatch(request(command: "--gap", args: ["rel:x"])),
    ]

    #expect(responses.allSatisfy { !$0.ok && $0.errorCode == .invalidRequest })
  }

  @Test("dispatch: rejects malformed focus arguments")
  func dispatchRejectsMalformedFocusArguments() {
    let manager = spaceManager()
    let handler = SpaceCommandHandler(
      spaceManager: manager,
      activeSpaceID: { 2 },
      spaces: { spaces(focusedIndex: 0) }
    )

    let responses = [
      handler.dispatch(request(command: "--focus", args: [])),
      handler.dispatch(request(command: "--focus", args: ["next", "extra"])),
      handler.dispatch(request(command: "--focus", args: ["unknown"])),
      handler.dispatch(request(command: "--focus", args: ["10"])),
      SpaceCommandHandler(spaceManager: manager, activeSpaceID: { 2 }, spaces: { [] })
        .dispatch(request(command: "--focus", args: ["next"])),
      SpaceCommandHandler(spaceManager: spaceManager(), activeSpaceID: { 2 }, spaces: { [] })
        .dispatch(request(command: "--focus", args: ["recent"])),
    ]

    #expect(responses.allSatisfy { !$0.ok && $0.errorCode == .invalidRequest })
  }

  @Test("dispatch: rejects unsupported space commands")
  func dispatchRejectsUnsupportedSpaceCommands() {
    let handler = SpaceCommandHandler(
      spaceManager: SpaceManager(activeSpaceIDResolver: { nil }),
      activeSpaceID: { 42 }
    )
    let response = handler.dispatch(request(command: "--unknown", args: []))

    #expect(response.ok == false)
    #expect(response.errorCode == .unsupportedCommand)
    #expect(response.message == "unsupported space command: --unknown")
  }

  @Test("dispatch: updates active space only")
  func dispatchUpdatesActiveSpaceOnly() {
    let manager = SpaceManager(activeSpaceIDResolver: { nil })
    let handler = SpaceCommandHandler(spaceManager: manager, activeSpaceID: { 2 })

    _ = handler.dispatch(request(command: "--gap", args: ["abs:10"]))

    #expect(manager.settings(for: 1).gap == 0)
    #expect(manager.settings(for: 2).gap == 10)
  }

  private func request(command: String, args: [String]) -> IPCRequest {
    IPCRequest(id: "request-id", domain: .space, command: command, args: args)
  }

  private func jsonObject(_ string: String) throws -> [String: Any] {
    let data = try #require(string.data(using: .utf8))
    let object = try JSONSerialization.jsonObject(with: data)
    return try #require(object as? [String: Any])
  }

  private func spaceManager(activeSpaceIDs: [UInt64?] = [nil]) -> SpaceManager {
    let resolver = ActiveSpaceIDSequence(activeSpaceIDs)
    return SpaceManager(activeSpaceIDResolver: resolver.next)
  }

  private func spaces(focusedIndex: Int?) -> [SpaceSerializer] {
    (0..<3).map { index in
      SpaceSerializer(
        id: UInt64(100 + index),
        uuid: nil,
        index: index,
        label: nil,
        type: "normal",
        display: nil,
        windows: [],
        hasFocus: index == focusedIndex,
        isVisible: false,
        isNativeFullscreen: false
      )
    }
  }
}

private final class ActiveSpaceIDSequence: @unchecked Sendable {
  private var values: [UInt64?]

  init(_ values: [UInt64?]) {
    self.values = values
  }

  func next() -> UInt64? {
    guard !values.isEmpty else { return nil }

    return values.removeFirst()
  }
}
