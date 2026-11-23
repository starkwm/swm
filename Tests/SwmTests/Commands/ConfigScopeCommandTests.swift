import ArgumentParser
import Darwin
import Testing

@testable import Swm
@testable import SwmLib

@Suite("Config scope CLI behavior")
struct ConfigScopeCommandTests {
  static let settings = [
    "layout", "master-ratio", "master-placement", "split-ratio", "preserve-split", "padding", "gap",
  ]

  @Test(
    "queries send the selected scope through the IPC client",
    arguments: settings,
    ["global", "current", "2"]
  )
  func queriesSendSelectedScope(setting: String, scope: String) throws {
    let selector = scope == "global" ? [] : ["--space", scope]
    var command = try #require(
      Arguments.parseAsRoot(["config", setting] + selector) as? any IPCCommand
    )
    let output = try #require(tmpfile())
    defer { fclose(output) }
    var sent = false
    try command.run(
      send: { domain, arguments in
        sent = true
        #expect(domain == (scope == "global" ? .config : .space))
        #expect(
          arguments == [(scope == "global" ? "" : "--") + setting] + (scope == "2" ? selector : [])
        )
        return Client.SendResult(ok: true, outputMessage: "")
      },
      output: output,
      errors: output
    )
    #expect(sent)
  }

  @Test("help exposes Space scope only on shared settings")
  func helpExposesScopeOnlyOnSharedSettings() {
    #expect(ConfigCommand.Gap.helpMessage().contains("--space"))
    #expect(ConfigCommand.Padding.helpMessage().contains("--top"))
    #expect(!ConfigCommand.FocusFollowsMouse.helpMessage().contains("--space"))
    #expect(!ConfigCommand.AnimationDuration.helpMessage().contains("--space"))
    #expect(!ConfigCommand.AnimationEasingCommand.helpMessage().contains("--space"))
    let help = SpaceCommand.helpMessage()
    #expect(help.contains("activate"))
    for setting in Self.settings {
      #expect(!help.contains(setting))
    }
  }

  @Test("shared settings reject invalid selectors", arguments: settings)
  func rejectsInvalidSelectors(setting: String) {
    for selector in [[], ["0"], ["-1"], ["next"], ["1.5"], ["999999999999999999999999"]] {
      #expect(throws: (any Error).self) {
        try Arguments.parseAsRoot(Arguments.resolve(["config", setting, "--space"] + selector))
      }
    }
  }

  @Test(
    "global-only settings reject Space selection",
    arguments: ["animation-duration", "animation-easing", "focus-follows-mouse"]
  )
  func globalOnlySettingsRejectSpaceSelection(setting: String) {
    for selector in ["current", "2"] {
      #expect(throws: (any Error).self) {
        try Arguments.parseAsRoot(["config", setting, "--space", selector])
      }
    }
  }

  @Test("removed Space setting commands fail", arguments: settings)
  func removedSpaceSettingsFail(setting: String) {
    #expect(throws: (any Error).self) {
      try Arguments.parseAsRoot(Arguments.resolve(["space", setting]))
    }
  }

  @MainActor
  @Test("gap changes preserve global defaults and independent Space adjustments")
  func gapChangesPreserveScopeBehavior() async throws {
    let spaces = Spaces(activeSpaceID: 10)
    let tiling = Tiling(
      snapshot: { TilingReconciliationSnapshot(windows: [], topology: nil) },
      spaces: spaces
    )
    let config = ConfigCommandHandler(
      windows: Windows(workspace: Workspace(), focusedWindowID: nil),
      spaces: spaces,
      tiling: tiling
    )
    let space = SpaceCommandHandler(spaces: spaces, tiling: tiling, spaceIDProvider: { [10, 20] })

    func send(_ arguments: [String]) async throws -> IPCResponse {
      let command = try #require(
        Arguments.parseAsRoot(Arguments.resolve(["config", "gap"] + arguments)) as? any IPCCommand
      )
      let request = IPCRequest(
        id: "gap",
        domain: command.requestDomain,
        command: command.commandArguments[0],
        args: Array(command.commandArguments.dropFirst())
      )
      return command.requestDomain == .space
        ? await space.dispatch(request) : config.dispatch(request)
    }

    #expect(try await send(["8"]).ok)
    #expect(try await send(["--space", "current", "+2"]).ok)
    #expect(try await send(["--space", "2", "-3"]).ok)
    #expect(try await send([]).message == "8")
    #expect(try await send(["--space", "current"]).message == "10")
    #expect(try await send(["--space", "2"]).message == "5")
    #expect(spaces.settings(for: 30).gap == 8)
    #expect(!(try await send(["--space", "3", "9"])).ok)
    #expect(try await send(["+1"]).ok)
    #expect(spaces.settings(for: 10).gap == 9)
    #expect(spaces.settings(for: 20).gap == 9)
    #expect(spaces.settings(for: 40).gap == 9)
  }
}
