import ArgumentParser
import Testing

@testable import Swm
@testable import SwmLib

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
        ["config", "padding", "--space", "current", "--top", "-4", "--"]
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

    #expect(help.contains("USAGE: swm window move [--window <window>] [--absolute] <x> <y>"))
    #expect(help.contains("swm window move [--window <window>] --display <target>"))
    #expect(help.contains("swm window move [--window <window>] --space <target>"))
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
      #expect(!script.contains("previous"))
    }
  }

  @Test(
    "parseAsRoot: navigation accepts prev and rejects previous",
    arguments: [
      (["window", "move", "--display"], IPCCommand.window(.display(.focused, .previous))),
      (["window", "move", "--space"], .window(.space(.focused, .previous))),
      (["window", "focus"], .window(.focusCycle(.prev))),
      (["window", "swap"], .window(.swapCycle(.prev))),
      (["display", "focus"], .displayFocus(.cyclic(.previous))),
    ]
  )
  func parseAsRootNavigationAcceptsPrevAndRejectsPrevious(
    path: [String],
    expected: IPCCommand
  ) throws {
    let command = try #require(
      Arguments.parseAsRoot(Arguments.resolve(path + ["prev"])) as? any DaemonCommand
    )
    #expect(command.ipcCommand == expected)
    #expect(throws: (any Error).self) {
      try Arguments.parseAsRoot(Arguments.resolve(path + ["previous"]))
    }
    let help = Arguments.helpMessage(for: type(of: command))
    #expect(help.contains("prev"))
    #expect(!help.contains("previous"))
  }

  @Test("parseAsRoot: translates window moves to IPC arguments")
  func parseAsRootTranslatesWindowMovesToIPCArguments() throws {
    let command = try #require(
      Arguments.parseAsRoot([
        "window", "move", "--window", "recent", "10", "20",
      ]) as? WindowCommand.Move
    )

    #expect(command.ipcCommand == .window(.move(.recent, .relative(IntPair(10, 20)))))
  }

  @Test("parseAsRoot: preserves warp selectors and focused defaults")
  func parseAsRootPreservesWarpSelectorsAndFocusedDefaults() throws {
    let focused = try #require(
      Arguments.parseAsRoot(["window", "warp"]) as? WindowCommand.Warp
    )

    #expect(focused.ipcCommand == .window(.warp(.selected(.focused))))

    for (selector, expected) in [
      ("recent", WindowSelection.recent),
      ("42", .id(42)),
    ] {
      let selected = try #require(
        Arguments.parseAsRoot(["window", "warp", selector]) as? WindowCommand.Warp
      )

      #expect(selected.ipcCommand == .window(.warp(.selected(expected))))
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
    arguments: [
      ("left", CardinalDirection.left),
      ("right", .right),
      ("up", .up),
      ("down", .down),
    ]
  )
  func parseAsRootPreservesDirectionalWarpArguments(
    direction: String,
    expected: CardinalDirection
  ) throws {
    let command = try #require(
      Arguments.parseAsRoot(["window", "warp", direction]) as? WindowCommand.Warp
    )

    #expect(command.ipcCommand == .window(.warp(.direction(expected))))
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
      (["window", "focus", "left"], IPCCommand.window(.focus(.direction(.left)))),
      (["window", "focus", "next"], .window(.focusCycle(.next))),
      (["window", "focus", "recent"], .window(.focus(.selected(.recent)))),
      (["window", "focus", "42"], .window(.focus(.selected(.id(42))))),
      (["window", "focus", "master"], .window(.focusMaster(.focused))),
      (["window", "swap", "up"], .window(.swap(.focused, .up))),
      (["window", "swap", "--window", "42", "up"], .window(.swap(.id(42), .up))),
      (["window", "swap", "prev"], .window(.swapCycle(.prev))),
      (["window", "swap", "--window", "recent", "master"], .window(.swapWithMaster(.recent))),
    ]
  )
  func parseAsRootMapsFocusAndSwapTargetsToDaemonCommands(
    arguments: [String],
    expected: IPCCommand
  ) throws {
    let command = try #require(Arguments.parseAsRoot(arguments) as? any DaemonCommand)

    #expect(command.ipcCommand == expected)
  }

  @Test("parseAsRoot: translates floating overrides and window selection")
  func parseAsRootTranslatesFloatingOverridesAndWindowSelection() throws {
    for (state, layout) in [
      ("on", WindowLayoutSelection.float),
      ("off", .tile),
      ("toggle", .toggle),
    ] {
      for (selectorArgs, selection) in [
        ([String](), WindowSelection.focused),
        (["--window", "recent"], .recent),
        (["--window", "42"], .id(42)),
      ] {
        let command = try #require(
          Arguments.parseAsRoot(["window", "float", state] + selectorArgs) as? WindowCommand.Float
        )
        #expect(command.ipcCommand == .window(.layout(selection, layout)))
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

    #expect(command.ipcCommand == .config(.gap(scope: .space(2), .absolute(10))))
  }

  @Test("parseAsRoot: translates one based Space activation indexes")
  func parseAsRootTranslatesOneBasedSpaceActivationIndexes() throws {
    let command = try #require(
      Arguments.parseAsRoot(["space", "activate", "2"]) as? SpaceCommand.Activate
    )
    #expect(command.ipcCommand == .spaceActivate(index: 2))
  }

  @Test("parseAsRoot: rejects missing and invalid Space activation indexes")
  func parseAsRootRejectsMissingAndInvalidSpaceActivationIndexes() {
    for args in [[], ["0"], ["-1"], ["next"], ["1", "2"]] {
      #expect(throws: (any Error).self) {
        try Arguments.parseAsRoot(["space", "activate"] + args)
      }
    }
  }

  @Test(
    "parseAsRoot: translates display focus targets",
    arguments: [
      ("2", DisplayTarget.cyclic(.index(2))),
      ("next", .cyclic(.next)),
      ("recent", .recent),
      ("up", .direction(.up)),
    ]
  )
  func parseAsRootTranslatesDisplayFocusTargets(target: String, expected: DisplayTarget) throws {
    let command = try #require(
      Arguments.parseAsRoot(["display", "focus", target]) as? DisplayCommand.Focus
    )
    #expect(command.ipcCommand == .displayFocus(expected))
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
    #expect(command.ipcCommand == .rule(.add(["label=finder", "app=^Finder$", "manage=off"])))
    let remove = try #require(
      Arguments.parseAsRoot(["rule", "remove", "finder"]) as? RuleCommand.Remove
    )
    #expect(remove.ipcCommand == .rule(.remove("finder")))
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

    #expect(command.ipcCommand == .config(.focusFollowsMouse(.autofocus)))
  }

  @Test(
    "parseAsRoot: sets plain values and adjusts signed ones",
    arguments: [
      (
        ["config", "gap", "--space", "current", "6"],
        IPCCommand.config(.gap(scope: .currentSpace, .absolute(6)))
      ),
      (
        ["config", "gap", "--space", "current", "+2"],
        .config(.gap(scope: .currentSpace, .relative(2)))
      ),
      (
        ["config", "gap", "--space", "current", "-2"],
        .config(.gap(scope: .currentSpace, .relative(-2)))
      ),
      (["config", "gap", "-2", "--space", "3"], .config(.gap(scope: .space(3), .relative(-2)))),
      (
        ["config", "master-ratio", "--space", "current", "0.6"],
        .config(.masterRatio(scope: .currentSpace, .absolute(0.6)))
      ),
      (
        ["config", "master-ratio", "--space", "current", "-0.05"],
        .config(.masterRatio(scope: .currentSpace, .relative(-0.05)))
      ),
      (["window", "split-ratio", "+0.05"], .window(.splitRatio(.focused, .relative(0.05)))),
      (
        ["config", "split-ratio", "0.6", "--space", "2"],
        .config(.splitRatio(scope: .space(2), .absolute(0.6)))
      ),
      (["config", "split-ratio", "-0.05"], .config(.splitRatio(scope: .global, .relative(-0.05)))),
      (
        ["config", "padding", "--space", "current", "--top", "8", "--left", "-4"],
        .config(
          .padding(
            scope: .currentSpace,
            [
              PaddingSideChange(side: .top, change: .absolute(8)),
              PaddingSideChange(side: .left, change: .relative(-4)),
            ]
          )
        )
      ),
      (
        ["config", "padding", "--bottom", "6", "--top", "-2"],
        .config(
          .padding(
            scope: .global,
            [
              PaddingSideChange(side: .top, change: .relative(-2)),
              PaddingSideChange(side: .bottom, change: .absolute(6)),
            ]
          )
        )
      ),
      (
        ["config", "padding", "--space=2", "-2"],
        .config(
          .padding(
            scope: .space(2),
            PaddingSide.allCases.map { PaddingSideChange(side: $0, change: .relative(-2)) }
          )
        )
      ),
      (
        ["config", "padding", "--top=6", "-2"],
        .config(
          .padding(
            scope: .global,
            [
              PaddingSideChange(side: .top, change: .absolute(6)),
              PaddingSideChange(side: .bottom, change: .relative(-2)),
              PaddingSideChange(side: .left, change: .relative(-2)),
              PaddingSideChange(side: .right, change: .relative(-2)),
            ]
          )
        )
      ),
      (["config", "gap", "6"], .config(.gap(scope: .global, .absolute(6)))),
      (["config", "gap", "-2"], .config(.gap(scope: .global, .relative(-2)))),
      (
        ["config", "master-ratio", "+0.05"], .config(.masterRatio(scope: .global, .relative(0.05)))
      ),
    ]
  )
  func parseAsRootSetsPlainValuesAndAdjustsSignedOnes(
    arguments: [String],
    expected: IPCCommand
  ) throws {
    let command = try #require(
      Arguments.parseAsRoot(Arguments.resolve(arguments)) as? any DaemonCommand
    )

    #expect(command.ipcCommand == expected)
  }

  @Test(
    "parseAsRoot: sends only the target for Space settings given without a value",
    arguments: [
      ("layout", IPCCommand.config(.layout(scope: .space(2), nil))),
      ("master-ratio", .config(.masterRatio(scope: .space(2), nil))),
      ("master-placement", .config(.masterPlacement(scope: .space(2), nil))),
      ("split-ratio", .config(.splitRatio(scope: .space(2), nil))),
      ("preserve-split", .config(.preserveSplit(scope: .space(2), nil))),
      ("gap", .config(.gap(scope: .space(2), nil))),
      ("padding", .config(.padding(scope: .space(2), []))),
    ]
  )
  func parseAsRootSendsOnlyTheTargetForSpaceSettingsGivenWithoutAValue(
    setting: String,
    expected: IPCCommand
  ) throws {
    let command = try #require(
      Arguments.parseAsRoot(["config", setting, "--space", "2"]) as? any DaemonCommand
    )

    #expect(command.ipcCommand == expected)
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
    #expect(command.ipcCommand == .rule(.add(["app=^Finder$", "grid=2:1:1:0:1:1", "display=2"])))
  }
}
