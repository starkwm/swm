import ArgumentParser
import Darwin
import Testing

@testable import Swm
@testable import SwmLib

@Suite("ConfigScopeCommand")
struct ConfigScopeCommandTests {
  static let settings = [
    "layout", "master-ratio", "master-placement", "split-ratio", "preserve-split", "padding", "gap",
  ]

  @Test(
    "parseAsRoot: queries send the selected scope through the IPC client",
    arguments: settings,
    ["global", "current", "2"]
  )
  func parseAsRootQueriesSendTheSelectedScopeThroughTheIPCClient(
    setting: String,
    scope: String
  ) throws {
    let selector = scope == "global" ? [] : ["--space", scope]
    var command = try #require(
      Arguments.parseAsRoot(["config", setting] + selector) as? any DaemonCommand
    )
    let expectedScope: ConfigScope =
      switch scope {
      case "global": .global
      case "current": .currentSpace
      default: .space(2)
      }
    let expectedCommand: IPCCommand =
      switch setting {
      case "layout": .config(.layout(scope: expectedScope, nil))
      case "master-ratio": .config(.masterRatio(scope: expectedScope, nil))
      case "master-placement": .config(.masterPlacement(scope: expectedScope, nil))
      case "split-ratio": .config(.splitRatio(scope: expectedScope, nil))
      case "preserve-split": .config(.preserveSplit(scope: expectedScope, nil))
      case "padding": .config(.padding(scope: expectedScope, []))
      default: .config(.gap(scope: expectedScope, nil))
      }
    let output = try #require(tmpfile())
    defer { fclose(output) }
    var sent = false
    try command.run(
      send: { ipcCommand in
        sent = true
        #expect(ipcCommand == expectedCommand)
        return Client.SendResult(ok: true, outputMessage: "")
      },
      output: output,
      errors: output
    )
    #expect(sent)
  }

  @Test("helpMessage: exposes Space scope only on shared settings")
  func helpMessageExposesSpaceScopeOnlyOnSharedSettings() {
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

  @Test("parseAsRoot: shared settings reject invalid selectors", arguments: settings)
  func parseAsRootSharedSettingsRejectInvalidSelectors(setting: String) {
    for selector in [[], ["0"], ["-1"], ["next"], ["1.5"], ["999999999999999999999999"]] {
      #expect(throws: (any Error).self) {
        try Arguments.parseAsRoot(Arguments.resolve(["config", setting, "--space"] + selector))
      }
    }
  }

  @Test(
    "parseAsRoot: global-only settings reject Space selection",
    arguments: ["animation-duration", "animation-easing", "focus-follows-mouse"]
  )
  func parseAsRootGlobalOnlySettingsRejectSpaceSelection(setting: String) {
    for selector in ["current", "2"] {
      #expect(throws: (any Error).self) {
        try Arguments.parseAsRoot(["config", setting, "--space", selector])
      }
    }
  }

  @Test("parseAsRoot: removed Space setting commands fail", arguments: settings)
  func parseAsRootRemovedSpaceSettingCommandsFail(setting: String) {
    #expect(throws: (any Error).self) {
      try Arguments.parseAsRoot(Arguments.resolve(["space", setting]))
    }
  }

  @MainActor
  @Test("gap: changes preserve global defaults and independent Space adjustments")
  func gapChangesPreserveGlobalDefaultsAndIndependentSpaceAdjustments() throws {
    let spaces = Spaces(activeSpaceID: 10)
    let tiling = Tiling(
      snapshot: { TilingReconciliationSnapshot(windows: [], topology: nil) },
      spaces: spaces
    )
    let config = ConfigCommandHandler(
      windows: Windows(workspace: Workspace(), focusedWindowID: nil),
      spaces: spaces,
      tiling: tiling,
      spaceIDProvider: { [10, 20] }
    )

    func send(_ arguments: [String]) throws -> IPCResponse {
      let command = try #require(
        Arguments.parseAsRoot(Arguments.resolve(["config", "gap"] + arguments))
          as? any DaemonCommand
      )
      guard case .config(let configCommand) = command.ipcCommand else {
        Issue.record("Expected config command")
        return .failure(id: "gap", message: "unexpected", errorCode: .invalidRequest)
      }
      return config.dispatch(id: "gap", command: configCommand)
    }

    #expect(try send(["8"]).ok)
    #expect(try send(["--space", "current", "+2"]).ok)
    #expect(try send(["--space", "2", "-3"]).ok)
    #expect(try send([]).message == "8")
    #expect(try send(["--space", "current"]).message == "10")
    #expect(try send(["--space", "2"]).message == "5")
    #expect(spaces.settings(for: 30).gap == 8)
    #expect(!(try send(["--space", "3", "9"])).ok)
    #expect(try send(["+1"]).ok)
    #expect(spaces.settings(for: 10).gap == 9)
    #expect(spaces.settings(for: 20).gap == 9)
    #expect(spaces.settings(for: 40).gap == 9)
  }
}
