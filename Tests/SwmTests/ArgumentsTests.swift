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
      #expect(
        Arguments.message(for: error).contains(
          "Please provide one of 'debug', 'info', 'warn' or 'error'."
        )
      )
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
      (["-v"], ["-v"]),
      (["help", "window", "focus"], ["help", "window", "focus"]),
      (["space", "activate", "--", "-1"], ["space", "activate", "--", "-1"]),
      (["config", "gap", "-2", "--space", "3"], ["config", "gap", "--space", "3", "--", "-2"]),
      (
        ["config", "padding", "--space", "current", "--top", "-4"],
        ["config", "padding", "--space", "current", "--top", "-4"]
      ),
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
        ["config", "ga", "6"],
        UnknownSubcommandError(name: "ga", path: "swm config", suggestion: "gap")
      ),
      (
        ["config", "bogus"],
        UnknownSubcommandError(name: "bogus", path: "swm config", suggestion: nil)
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
    #expect(help.contains("CONTROL SUBCOMMANDS:"))
    #expect(help.contains("CONFIGURE SUBCOMMANDS:"))
    #expect(help.contains("INSPECT SUBCOMMANDS:"))
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

    #expect(
      help.contains(
        "USAGE: swm window move [--window <window>] [--absolute] [<x>] [<y>] [--display <display>] [--space <space>]"
      )
    )
    #expect(help.contains("Horizontal position or offset in points."))
    #expect(help.contains("swm window move -20 0"))
  }

  @Test("completionScript: includes commands and typed values")
  func completionScriptIncludesCommandsAndTypedValues() {
    for shell in CompletionShell.allCases {
      let script = Arguments.completionScript(for: shell)

      #expect(script.contains("swm"))
      #expect(script.contains("focus-follows-mouse"))
      #expect(script.contains("warp"))
      #expect(script.contains("autofocus"))
      #expect(script.contains("ease-out-circ"))
      #expect(script.contains("recent"))
      #expect(script.contains("next"))
      #expect(script.contains("prev"))
    }
  }

  @Test("parseAsRoot: translates window moves to IPC arguments")
  func parseAsRootTranslatesWindowMovesToIPCArguments() throws {
    let command = try #require(
      Arguments.parseAsRoot([
        "window", "move", "--window", "recent", "10", "20",
      ]) as? WindowCommand.Move
    )

    #expect(command.commandArguments == ["--move", "recent", "rel:10:20"])
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
        Arguments.parseAsRoot(["window", "warp", selector]) as? WindowCommand.Warp
      )

      #expect(selected.arguments == [selector])
    }

    #expect(
      Arguments.helpMessage(for: WindowCommand.Warp.self).contains(
        "USAGE: swm window warp [<target>]"
      )
    )
    #expect(throws: (any Error).self) {
      try Arguments.parseAsRoot(["window", "warp", "--window", "42"])
    }
  }

  @Test(
    "parseAsRoot: preserves directional warp arguments",
    arguments: ["left", "right", "up", "down"]
  )
  func parseAsRootPreservesDirectionalWarpArguments(direction: String) throws {
    let command = try #require(
      Arguments.parseAsRoot(["window", "warp", direction]) as? WindowCommand.Warp
    )

    #expect(command.arguments == [direction])
  }

  @Test("parseAsRoot: rejects conflicting warp targets and invalid directions")
  func parseAsRootRejectsConflictingWarpTargetsAndInvalidDirections() {
    for args in [
      ["--window", "recent"], ["recent", "left"], ["sideways"], ["master"],
      ["next"], ["prev"], ["0"], ["4294967296"],
    ] {
      #expect(throws: (any Error).self) {
        try Arguments.parseAsRoot(["window", "warp"] + args)
      }
    }
  }

  @Test(
    "parseAsRoot: maps focus and swap targets to daemon commands",
    arguments: [
      (["window", "focus", "left"], ["--focus", "left"]),
      (["window", "focus", "next"], ["--cycle", "next"]),
      (["window", "focus", "recent"], ["--focus", "recent"]),
      (["window", "focus", "42"], ["--focus", "42"]),
      (["window", "focus", "master"], ["--focus-master"]),
      (["window", "swap", "up"], ["--swap", "up"]),
      (["window", "swap", "--window", "42", "up"], ["--swap", "42", "up"]),
      (["window", "swap", "prev"], ["--swap-cycle", "prev"]),
      (["window", "swap", "--window", "recent", "master"], ["--swap-with-master", "recent"]),
    ]
  )
  func parseAsRootMapsFocusAndSwapTargetsToDaemonCommands(
    arguments: [String],
    expected: [String]
  ) throws {
    let command = try #require(Arguments.parseAsRoot(arguments) as? any IPCCommand)

    #expect(command.commandArguments == expected)
  }

  @Test("parseAsRoot: translates floating overrides and window selection")
  func parseAsRootTranslatesFloatingOverridesAndWindowSelection() throws {
    for (state, value) in [("on", "float"), ("off", "tile"), ("toggle", "toggle")] {
      for selector in [[], ["--window", "recent"], ["--window", "42"]] {
        let command = try #require(
          Arguments.parseAsRoot(["window", "float", state] + selector) as? WindowCommand.Float
        )
        #expect(command.commandArguments == ["--layout"] + selector.suffix(1) + [value])
      }
    }
    for args in [["layout", "float"], ["float"], ["float", "tile"], ["float", "float"]] {
      #expect(throws: (any Error).self) {
        try Arguments.parseAsRoot(Arguments.resolve(["window"] + args))
      }
    }
  }

  @Test("parseAsRoot: translates Space settings selectors")
  func parseAsRootTranslatesSpaceSettingsSelectors() throws {
    let command = try #require(
      Arguments.parseAsRoot([
        "config", "gap", "--space", "2", "10",
      ]) as? ConfigCommand.Gap
    )

    #expect(command.arguments == ["--space", "2", "abs:10"])
  }

  @Test("parseAsRoot: translates one based Space activation indexes")
  func parseAsRootTranslatesOneBasedSpaceActivationIndexes() throws {
    let command = try #require(
      Arguments.parseAsRoot(["space", "activate", "2"]) as? SpaceCommand.Activate
    )
    #expect(command.arguments == ["2"])
    #expect(SpaceCommand.Activate.command == "--activate")
    #expect(SpaceCommand.Activate.domain == .space)
  }

  @Test("parseAsRoot: rejects missing and invalid Space activation indexes")
  func parseAsRootRejectsMissingAndInvalidSpaceActivationIndexes() {
    for args in [[], ["0"], ["-1"], ["next"], ["1", "2"]] {
      #expect(throws: (any Error).self) {
        try Arguments.parseAsRoot(["space", "activate"] + args)
      }
    }
  }

  @Test("parseAsRoot: translates display focus targets", arguments: ["2", "next", "recent", "up"])
  func parseAsRootTranslatesDisplayFocusTargets(target: String) throws {
    let command = try #require(
      Arguments.parseAsRoot(["display", "focus", target]) as? DisplayCommand.Focus
    )
    #expect(command.commandArguments == ["--focus", target])
    #expect(DisplayCommand.Focus.domain == .display)
  }

  @Test("parseAsRoot: rejects missing and invalid display focus targets")
  func parseAsRootRejectsMissingAndInvalidDisplayFocusTargets() {
    for args in [[], ["0"], ["-1"], ["north"], ["1", "2"]] {
      #expect(throws: (any Error).self) {
        try Arguments.parseAsRoot(["display", "focus"] + args)
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

  @Test(
    "parseAsRoot: rejects missing, unknown, and conflicting focus and swap targets",
    arguments: [
      ["window", "focus"], ["window", "focus", "sideways"], ["window", "swap", "recent"],
      ["window", "swap", "--window", "42", "next"],
    ]
  )
  func parseAsRootRejectsMissingUnknownAndConflictingFocusAndSwapTargets(arguments: [String]) {
    #expect(throws: (any Error).self) {
      try Arguments.parseAsRoot(arguments)
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

  @Test(
    "parseAsRoot: sets plain values and adjusts signed ones",
    arguments: [
      (["config", "gap", "--space", "current", "6"], ["abs:6"]),
      (["config", "gap", "--space", "current", "+2"], ["rel:2"]),
      (["config", "gap", "--space", "current", "-2"], ["rel:-2"]),
      (["config", "gap", "-2", "--space", "3"], ["--space", "3", "rel:-2"]),
      (["config", "master-ratio", "--space", "current", "0.6"], ["abs:0.6"]),
      (["config", "master-ratio", "--space", "current", "-0.05"], ["rel:-0.05"]),
      (["window", "split-ratio", "+0.05"], ["rel:0.05"]),
      (["config", "split-ratio", "0.6", "--space", "2"], ["--space", "2", "abs:0.6"]),
      (["config", "split-ratio", "-0.05"], ["rel:-0.05"]),
      (
        ["config", "padding", "--space", "current", "--top", "8", "--left", "-4"],
        ["top=abs:8", "left=rel:-4"]
      ),
      (["config", "padding", "--bottom", "6", "--top", "-2"], ["top=rel:-2", "bottom=abs:6"]),
      (
        ["config", "padding", "--space=2", "-2"],
        ["--space", "2", "top=rel:-2", "bottom=rel:-2", "left=rel:-2", "right=rel:-2"]
      ),
      (
        ["config", "padding", "--top=6", "-2"],
        ["top=abs:6", "bottom=rel:-2", "left=rel:-2", "right=rel:-2"]
      ),
      (["config", "gap", "6"], ["abs:6"]),
      (["config", "gap", "-2"], ["rel:-2"]),
      (["config", "master-ratio", "+0.05"], ["rel:0.05"]),
    ]
  )
  func parseAsRootSetsPlainValuesAndAdjustsSignedOnes(
    arguments: [String],
    expected: [String]
  ) throws {
    let command = try #require(
      Arguments.parseAsRoot(Arguments.resolve(arguments)) as? any IPCCommand
    )

    #expect(command.arguments == expected)
  }

  @Test(
    "parseAsRoot: sends only the target for Space settings given without a value",
    arguments: [
      ["layout"], ["master-ratio"], ["master-placement"], ["split-ratio"], ["preserve-split"],
      ["gap"],
      ["padding"],
    ]
  )
  func parseAsRootSendsOnlyTheTargetForSpaceSettingsGivenWithoutAValue(setting: [String]) throws {
    let command = try #require(
      Arguments.parseAsRoot(["config"] + setting + ["--space", "2"]) as? any IPCCommand
    )

    #expect(command.arguments == ["--space", "2"])
  }

  @Test(
    "parseAsRoot: rejects out-of-range ratios and malformed values",
    arguments: [
      ["config", "master-ratio", "--space", "current", "5"], ["window", "split-ratio", "0.05"],
      ["config", "split-ratio", "--space", "current", "0.95"], ["config", "master-ratio", "0.05"],
      ["config", "gap", "--space", "current", "wide"],
      ["config", "gap", "--space", "current", "rel:4"],
      ["config", "gap", "--space", "current", "abs:6"], ["config", "gap", "rel:4"],
    ]
  )
  func parseAsRootRejectsOutOfRangeRatiosAndMalformedValues(
    arguments: [String]
  ) {
    #expect(throws: (any Error).self) {
      try Arguments.parseAsRoot(Arguments.resolve(arguments))
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
