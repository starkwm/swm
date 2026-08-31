import ArgumentParser
import Testing

@testable import Swm

@Suite("Arguments")
struct ArgumentsTests {
  @Test("root help groups command domains")
  func rootHelpGroupsCommandDomains() {
    let help = Arguments.helpMessage()

    #expect(help.contains("DAEMON SUBCOMMANDS:"))
    #expect(help.contains("WINDOW SUBCOMMANDS:"))
    #expect(help.contains("OTHER SUBCOMMANDS:"))
    #expect(help.contains("See 'swm help <subcommand>' for detailed help."))
    #expect(help.contains("--version"))
    #expect(!help.contains("<args>"))
  }

  @Test("subcommand help omits the top-level version flag")
  func subcommandHelpOmitsTopLevelVersionFlag() {
    let domainHelp = Arguments.helpMessage(for: WindowCommand.self)
    let commandHelp = Arguments.helpMessage(for: WindowCommand.Move.self)

    #expect(!domainHelp.contains("--version"))
    #expect(!commandHelp.contains("--version"))
  }

  @Test("leaf help describes exact command arguments")
  func leafHelpDescribesExactCommandArguments() {
    let help = Arguments.helpMessage(for: WindowCommand.Move.self)

    #expect(help.contains("USAGE: swm window move [--window <window>] <position>"))
    #expect(help.contains("Position in the form abs|rel:<x>:<y>."))
  }

  @Test("typed window command translates to IPC arguments")
  func typedWindowCommandTranslatesToIPCArguments() throws {
    let command = try #require(
      Arguments.parseAsRoot([
        "window", "move", "--window", "recent", "rel:10:20",
      ]) as? WindowCommand.Move
    )

    #expect(command.arguments == ["recent", "rel:10:20"])
  }

  @Test("typed directional window command translates to IPC arguments")
  func typedDirectionalWindowCommandTranslatesToIPCArguments() throws {
    let command = try #require(
      Arguments.parseAsRoot([
        "window", "focus", "--direction", "left",
      ]) as? WindowCommand.Focus
    )

    #expect(command.arguments == ["left"])
  }

  @Test("typed space command translates a space selector to IPC arguments")
  func typedSpaceCommandTranslatesSpaceSelectorToIPCArguments() throws {
    let command = try #require(
      Arguments.parseAsRoot([
        "space", "gap", "--space", "2", "abs:10",
      ]) as? SpaceCommand.Gap
    )

    #expect(command.arguments == ["--space", "2", "abs:10"])
  }

  @Test("typed window command rejects multiple targets")
  func typedWindowCommandRejectsMultipleTargets() {
    #expect(throws: (any Error).self) {
      try Arguments.parseAsRoot([
        "window", "focus", "--window", "recent", "--direction", "left",
      ])
    }
  }

  @Test("typed focus follows mouse command translates to IPC arguments")
  func typedFocusFollowsMouseCommandTranslatesToIPCArguments() throws {
    let command = try #require(
      Arguments.parseAsRoot([
        "config", "focus-follows-mouse", "autofocus",
      ]) as? ConfigCommand.FocusFollowsMouse
    )

    #expect(command.arguments == ["autofocus"])
  }
}
