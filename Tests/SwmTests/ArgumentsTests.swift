import ArgumentParser
import Testing

@testable import Swm

@Suite("Arguments")
struct ArgumentsTests {
  @Test("parseAsRoot: parses the start log level", arguments: ["debug", "info", "warn", "error"])
  func parseAsRootParsesTheStartLogLevel(value: String) throws {
    let command = try #require(
      Arguments.parseAsRoot(["start", "--log-level", value]) as? StartCommand
    )
    #expect(command.logLevel.rawValue == value)
  }

  @Test("parseAsRoot: defaults the log level and rejects unknown values")
  func parseAsRootDefaultsTheLogLevelAndRejectsUnknownValues() throws {
    let command = try #require(Arguments.parseAsRoot(["start"]) as? StartCommand)
    #expect(command.logLevel.rawValue == "info")
    do {
      _ = try Arguments.parseAsRoot(["start", "--log-level", "verbose"])
      Issue.record("Expected invalid log level")
    } catch {
      #expect(Arguments.message(for: error).contains("Invalid log level: verbose"))
    }
  }

  @Test(
    "resolve: starts the daemon without a subcommand",
    arguments: [
      ([], ["start"]),
      (["--config", "swmrc"], ["start", "--config", "swmrc"]),
      (["-c", "swmrc"], ["start", "-c", "swmrc"]),
      (["--log-level=debug"], ["start", "--log-level=debug"]),
      (["--version"], ["--version"]),
      (["window", "space", "next"], ["window", "space", "next"]),
      (["help", "window", "focus"], ["help", "window", "focus"]),
      (["space", "activate", "--", "-1"], ["space", "activate", "--", "-1"]),
    ]
  )
  func resolveStartsTheDaemonWithoutASubcommand(arguments: [String], expected: [String]) throws {
    #expect(try Arguments.resolve(arguments) == expected)
  }

  @Test(
    "resolve: reports unknown subcommands with suggestions",
    arguments: [
      (["windo"], UnknownSubcommandError(name: "windo", path: "swm", suggestion: "window")),
      (
        ["help", "windo"],
        UnknownSubcommandError(name: "windo", path: "swm", suggestion: "window")
      ),
      (
        ["window", "focs"],
        UnknownSubcommandError(name: "focs", path: "swm window", suggestion: "focus")
      ),
      (
        ["config", "gap", "6"],
        UnknownSubcommandError(name: "gap", path: "swm config", suggestion: "window-gap")
      ),
      (
        ["config", "padding", "6"],
        UnknownSubcommandError(name: "padding", path: "swm config", suggestion: nil)
      ),
      (["version"], UnknownSubcommandError(name: "version", path: "swm", suggestion: nil)),
    ]
  )
  func resolveReportsUnknownSubcommandsWithSuggestions(
    arguments: [String],
    expected: UnknownSubcommandError
  ) {
    #expect(throws: expected) {
      try Arguments.resolve(arguments)
    }
  }

  @Test("UnknownSubcommandError: points at the parent command help")
  func unknownSubcommandErrorPointsAtTheParentCommandHelp() {
    let error = UnknownSubcommandError(name: "focs", path: "swm window", suggestion: "focus")

    #expect(
      error.description == """
        Error: Unknown subcommand 'focs' for 'swm window'. Did you mean 'focus'?
          See 'swm window --help' for available subcommands.
        """
    )
  }

  @Test("helpMessage: groups command domains")
  func helpMessageGroupsCommandDomains() {
    let help = Arguments.helpMessage()

    #expect(help.contains("DAEMON SUBCOMMANDS:"))
    #expect(help.contains("WINDOW SUBCOMMANDS:"))
    #expect(help.contains("OTHER SUBCOMMANDS:"))
    #expect(help.contains("See 'swm help <subcommand>' for detailed help."))
    #expect(help.contains("--version"))
    #expect(!help.contains("<args>"))
  }

  @Test("helpMessage: omits the root version flag from subcommands")
  func helpMessageOmitsTheRootVersionFlagFromSubcommands() {
    let domainHelp = Arguments.helpMessage(for: WindowCommand.self)
    let commandHelp = Arguments.helpMessage(for: WindowCommand.Move.self)

    #expect(!domainHelp.contains("--version"))
    #expect(!commandHelp.contains("--version"))
  }

  @Test("helpMessage: describes leaf arguments")
  func helpMessageDescribesLeafArguments() {
    let help = Arguments.helpMessage(for: WindowCommand.Move.self)

    #expect(help.contains("USAGE: swm window move [--window <window>] <position>"))
    #expect(help.contains("Position in the form abs|rel:<x>:<y>."))
  }

  @Test("completionScript: includes commands and typed values")
  func completionScriptIncludesCommandsAndTypedValues() {
    for shell in CompletionShell.allCases {
      let script = Arguments.completionScript(for: shell)

      #expect(script.contains("swm"))
      #expect(script.contains("focus-follows-mouse"))
      #expect(script.contains("warp"))
      #expect(script.contains("autofocus"))
      #expect(script.contains("recent"))
      #expect(script.contains("next"))
      #expect(script.contains("prev"))
    }
  }

  @Test("parseAsRoot: translates window moves to IPC arguments")
  func parseAsRootTranslatesWindowMovesToIPCArguments() throws {
    let command = try #require(
      Arguments.parseAsRoot([
        "window", "move", "--window", "recent", "rel:10:20",
      ]) as? WindowCommand.Move
    )

    #expect(command.arguments == ["recent", "rel:10:20"])
  }

  @Test("parseAsRoot: preserves warp selectors and focused defaults")
  func parseAsRootPreservesWarpSelectorsAndFocusedDefaults() throws {
    let focused = try #require(
      Arguments.parseAsRoot(["window", "warp"]) as? WindowCommand.Warp
    )

    #expect(focused.arguments.isEmpty)
    #expect(WindowCommand.Warp.command == "--warp")

    for selector in ["recent", "42"] {
      let selected = try #require(
        Arguments.parseAsRoot(["window", "warp", "--window", selector]) as? WindowCommand.Warp
      )

      #expect(selected.arguments == [selector])
    }

    #expect(
      Arguments.helpMessage(for: WindowCommand.Warp.self).contains(
        "USAGE: swm window warp [--window <window>]"
      )
    )
    #expect(throws: (any Error).self) {
      try Arguments.parseAsRoot(["window", "warp", "42"])
    }
  }

  @Test(
    "parseAsRoot: preserves directional warp arguments",
    arguments: ["left", "right", "up", "down"]
  )
  func parseAsRootPreservesDirectionalWarpArguments(direction: String) throws {
    let command = try #require(
      Arguments.parseAsRoot(["window", "warp", "--direction", direction]) as? WindowCommand.Warp
    )

    #expect(command.arguments == [direction])
    #expect(command.selector.window == nil)
  }

  @Test("parseAsRoot: rejects conflicting warp targets and invalid directions")
  func parseAsRootRejectsConflictingWarpTargetsAndInvalidDirections() {
    #expect(throws: (any Error).self) {
      try Arguments.parseAsRoot(["window", "warp", "--window", "recent", "--direction", "left"])
    }
    #expect(throws: (any Error).self) {
      try Arguments.parseAsRoot(["window", "warp", "--direction", "sideways"])
    }
  }

  @Test("parseAsRoot: translates directional focus to IPC arguments")
  func parseAsRootTranslatesDirectionalFocusToIPCArguments() throws {
    let command = try #require(
      Arguments.parseAsRoot([
        "window", "focus", "--direction", "left",
      ]) as? WindowCommand.Focus
    )

    #expect(command.arguments == ["left"])
  }

  @Test("parseAsRoot: translates window Space selectors and destinations")
  func parseAsRootTranslatesWindowSpaceSelectorsAndDestinations() throws {
    let command = try #require(
      Arguments.parseAsRoot(["window", "space", "--window", "recent", "0"]) as? WindowCommand.Space
    )

    #expect(command.arguments == ["recent", "0"])
    #expect(WindowCommand.Space.command == "--space")

    let focused = try #require(
      Arguments.parseAsRoot(["window", "space", "next"]) as? WindowCommand.Space
    )

    #expect(focused.arguments == ["next"])
  }

  @Test("parseAsRoot: translates Space settings selectors")
  func parseAsRootTranslatesSpaceSettingsSelectors() throws {
    let command = try #require(
      Arguments.parseAsRoot([
        "space", "gap", "--space", "2", "abs:10",
      ]) as? SpaceCommand.Gap
    )

    #expect(command.arguments == ["--space", "2", "abs:10"])
  }

  @Test("parseAsRoot: translates zero based Space activation indexes")
  func parseAsRootTranslatesZeroBasedSpaceActivationIndexes() throws {
    let command = try #require(
      Arguments.parseAsRoot(["space", "activate", "2"]) as? SpaceCommand.Activate
    )
    #expect(command.arguments == ["2"])
    #expect(SpaceCommand.Activate.command == "--activate")
    #expect(SpaceCommand.Activate.domain == .space)
  }

  @Test("parseAsRoot: rejects missing and invalid Space activation indexes")
  func parseAsRootRejectsMissingAndInvalidSpaceActivationIndexes() {
    for args in [[], ["-1"], ["next"], ["0", "1"]] {
      #expect(throws: (any Error).self) {
        try Arguments.parseAsRoot(["space", "activate"] + args)
      }
    }
  }

  @Test("parseAsRoot: preserves rule registration and removal arguments")
  func parseAsRootPreservesRuleRegistrationAndRemovalArguments() throws {
    let command = try #require(
      Arguments.parseAsRoot([
        "rule", "add", "label=finder", "app=^Finder$", "manage=off",
      ]) as? RuleCommand.Add
    )
    #expect(command.arguments == ["label=finder", "app=^Finder$", "manage=off"])
    #expect(RuleCommand.Add.domain == .rule)
    #expect(RuleCommand.Add.command == "--add")
    let remove = try #require(
      Arguments.parseAsRoot(["rule", "remove", "finder"]) as? RuleCommand.Remove
    )
    #expect(remove.arguments == ["finder"])
    #expect(try Arguments.parseAsRoot(["rule", "list"]) is RuleCommand.List)
  }

  @Test("parseAsRoot: rejects conflicting focus targets")
  func parseAsRootRejectsConflictingFocusTargets() {
    #expect(throws: (any Error).self) {
      try Arguments.parseAsRoot([
        "window", "focus", "--window", "recent", "--direction", "left",
      ])
    }
  }

  @Test("parseAsRoot: translates focus follows mouse settings")
  func parseAsRootTranslatesFocusFollowsMouseSettings() throws {
    let command = try #require(
      Arguments.parseAsRoot([
        "config", "focus-follows-mouse", "autofocus",
      ]) as? ConfigCommand.FocusFollowsMouse
    )

    #expect(command.arguments == ["autofocus"])
  }

  @Test("parseAsRoot: preserves integer config values")
  func parseAsRootPreservesIntegerConfigValues() throws {
    let commandNames = [
      "window-gap", "top-padding", "right-padding", "bottom-padding", "left-padding",
    ]

    for commandName in commandNames {
      let command = try #require(
        Arguments.parseAsRoot(["config", commandName, "6"]) as? any ConfigIPCCommand
      )

      #expect(command.arguments == ["6"])
    }
  }

  @Test("parseAsRoot: preserves rule placement arguments")
  func parseAsRootPreservesRulePlacementArguments() throws {
    let command = try #require(
      Arguments.parseAsRoot([
        "rule", "add", "app=^Finder$", "grid=2:1:1:0:1:1", "display=2",
      ]) as? RuleCommand.Add
    )
    #expect(command.arguments == ["app=^Finder$", "grid=2:1:1:0:1:1", "display=2"])
  }
}
