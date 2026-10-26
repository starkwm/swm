import ArgumentParser
import Foundation
import SwmLib

/// Root command for the swm executable.
struct Arguments: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "swm",
    abstract: "Stark Window Manager for macOS.",
    groupedSubcommands: [
      CommandGroup(name: "DAEMON", subcommands: [StartCommand.self, ReloadCommand.self]),
      CommandGroup(name: "CONTROL", subcommands: [WindowCommand.self, SpaceCommand.self]),
      CommandGroup(
        name: "CONFIGURE",
        subcommands: [ConfigCommand.self, RuleCommand.self, SignalCommand.self]
      ),
      CommandGroup(name: "INSPECT", subcommands: [QueryCommand.self]),
    ]
  )

  /// Prepare raw arguments for parsing.
  ///
  /// No arguments, or leading `start` options, start the daemon. Any other leading
  /// word must name a subcommand, so a typo is reported instead of reaching `start`.
  /// Negative numbers are escaped for commands that accept signed adjustments.
  static func resolve(_ arguments: [String]) throws -> [String] {
    guard let first = arguments.first else { return [StartCommand._commandName] }
    if StartCommand.isOption(first) {
      return [StartCommand._commandName] + arguments
    }

    var subcommands = configuration.subcommands
    var path = [_commandName]
    var command: ParsableCommand.Type?
    for argument in arguments.drop(while: { $0 == "help" }) {
      guard !argument.hasPrefix("-"), !subcommands.isEmpty else { break }
      let names = subcommands.map { $0._commandName }
      guard let index = names.firstIndex(of: argument) else {
        throw UnknownSubcommandError(
          name: argument,
          path: path.joined(separator: " "),
          suggestion: closestName(to: argument, in: names)
        )
      }
      command = subcommands[index]
      subcommands = subcommands[index].configuration.subcommands
      path.append(argument)
    }
    if let command = command as? any SettingChangeCommand.Type {
      return command.escapingNegativeNumbers(arguments)
    }
    return arguments
  }

  /// The only candidate that shares a word with `name` or that `name` prefixes, else one
  /// within two edits.
  static func closestName(to name: String, in candidates: [String]) -> String? {
    let words = Set(name.split(separator: "-"))
    let partial = candidates.filter {
      $0.hasPrefix(name) || !words.isDisjoint(with: $0.split(separator: "-"))
    }
    if partial.count == 1 { return partial[0] }

    return
      candidates
      .map { ($0, editDistance(name, $0)) }
      .filter { $0.1 <= 2 }
      .min { $0.1 < $1.1 }?
      .0
  }

  /// Levenshtein distance between two strings.
  private static func editDistance(_ source: String, _ target: String) -> Int {
    let target = Array(target)
    var previous = Array(0...target.count)
    for (sourceIndex, sourceCharacter) in source.enumerated() {
      var current = [sourceIndex + 1]
      for (targetIndex, targetCharacter) in target.enumerated() {
        let substitution = previous[targetIndex] + (sourceCharacter == targetCharacter ? 0 : 1)
        current.append(min(previous[targetIndex + 1] + 1, current[targetIndex] + 1, substitution))
      }
      previous = current
    }
    return previous[target.count]
  }

  /// Show version information.
  @Flag(name: .long, help: "Show the version.")
  var version = false

  /// Print the version, or the root help when no subcommand was given.
  func run() throws {
    guard version else { throw CleanExit.helpRequest(self) }
    print("swm version \(Version.current.value)")
  }
}

/// Run the configuration file again in the running daemon.
struct ReloadCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "reload",
    abstract: "Run the configuration file again in the running daemon.",
    discussion: """
      Removes every rule and signal first, because the file registers them again. Settings \
      the file no longer sets keep their current values.
      """
  )

  /// Path to the configuration file, defaulting to the one `start` uses.
  @Option(
    name: .shortAndLong,
    help: ArgumentHelp("Path to the configuration file.", valueName: "path"),
    completion: .file()
  )
  var config: String?

  mutating func run() throws {
    try run(send: Client.send, execute: { try Config.exec(path: $0) }, errors: stderr)
  }

  /// Clear rules and signals, then execute the configuration file.
  func run(
    send: (CommandDomain, [String]) -> Client.SendResult,
    execute: (String) throws -> Void,
    errors: UnsafeMutablePointer<FILE>
  ) throws {
    for domain in [CommandDomain.rule, .signal] {
      let result = send(domain, ["--clear"])
      guard result.ok else {
        fputs("\(result.outputMessage)\n", errors)
        throw ExitCode.failure
      }
    }

    do {
      try execute(config ?? StartCommand.defaultConfigPath)
    } catch {
      fputs("Error: \(error)\n", errors)
      throw ExitCode.failure
    }
  }
}

/// A leading word that does not name a subcommand of the command before it.
struct UnknownSubcommandError: Error, Equatable, CustomStringConvertible {
  /// The unrecognized word.
  let name: String

  /// The command path the word followed, such as `swm window`.
  let path: String

  /// A similarly named subcommand, if one exists.
  let suggestion: String?

  /// Usage error text written to standard error.
  var description: String {
    var message = "Error: Unknown subcommand '\(name)' for '\(path)'."
    if let suggestion {
      message += " Did you mean '\(suggestion)'?"
    }
    return message + "\n  See '\(path) --help' for available subcommands."
  }
}

/// Start the window manager daemon.
struct StartCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "start",
    abstract: "Start the window manager daemon.",
    discussion: "Runs when swm is given no subcommand."
  )

  /// Conventional configuration path used when `--config` is omitted.
  static let defaultConfigPath = FileManager
    .default
    .homeDirectoryForCurrentUser
    .appending(path: ".config/swm/swmrc")
    .path()

  /// Whether a leading argument is a `start` option, which implies `start`.
  static func isOption(_ argument: String) -> Bool {
    let name = argument.split(separator: "=", maxSplits: 1).first.map(String.init) ?? argument
    return ["-c", "--config", "--log-level"].contains(name)
  }

  /// Path to the user configuration file executed at daemon startup.
  @Option(
    name: .shortAndLong,
    help: ArgumentHelp("Path to the configuration file.", valueName: "path"),
    completion: .file()
  )
  var config: String?

  /// Minimum runtime log level.
  @Option(name: .long, help: "Minimum log level.")
  var logLevel: LogLevel = .info

  /// Start the daemon using the parsed options.
  mutating func run() {
    MainActor.assumeIsolated {
      runSwm(with: self)
    }
  }
}

extension LogLevel: ExpressibleByArgument {}
