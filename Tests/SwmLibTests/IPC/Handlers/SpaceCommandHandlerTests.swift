import Foundation
import Testing

@testable import SwmLib

@Suite("SpaceCommandHandler")
struct SpaceCommandHandlerTests {
  @Test("dispatch: accepts toggle commands")
  func dispatchAcceptsToggleCommands() throws {
    let manager = SpaceManager()
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
    let manager = SpaceManager()
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
    let manager = SpaceManager()
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

  @Test("dispatch: rejects malformed arguments")
  func dispatchRejectsMalformedArguments() {
    let handler = SpaceCommandHandler(activeSpaceID: { 42 })

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

  @Test("dispatch: rejects unsupported space commands")
  func dispatchRejectsUnsupportedSpaceCommands() {
    let handler = SpaceCommandHandler(activeSpaceID: { 42 })
    let response = handler.dispatch(request(command: "--unknown", args: []))

    #expect(response.ok == false)
    #expect(response.errorCode == .unsupportedCommand)
    #expect(response.message == "unsupported space command: --unknown")
  }

  @Test("dispatch: updates active space only")
  func dispatchUpdatesActiveSpaceOnly() {
    let manager = SpaceManager()
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
}
