import ArgumentParser
import Foundation
import SwmLib

struct Arguments: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "swm",
    abstract: "Stark Window Manager for macOS.",
    groupedSubcommands: [
      CommandGroup(name: "DAEMON", subcommands: [StartCommand.self, ReloadCommand.self]),
      CommandGroup(
        name: "CONTROL",
        subcommands: [WindowCommand.self, SpaceCommand.self, DisplayCommand.self]
      ),
      CommandGroup(
        name: "CONFIGURE",
        subcommands: [ConfigCommand.self, RuleCommand.self, SignalCommand.self]
      ),
      CommandGroup(name: "INSPECT", subcommands: [QueryCommand.self]),
    ]
  )

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
    if let command = command as? any SignedPositionalCommand.Type, first != "help" {
      let prefixCount = path.count - 1
      return Array(arguments.prefix(prefixCount))
        + command.escapingPositionals(Array(arguments.dropFirst(prefixCount)))
    }
    return arguments
  }

  static func closestName(to name: String, in candidates: [String]) -> String? {
    let partial = candidates.filter {
      $0.hasPrefix(name) || $0.split(separator: "-").contains(Substring(name))
    }
    if partial.count == 1 { return partial[0] }

    return
      candidates
      .map { ($0, editDistance(name, $0)) }
      .filter { $0.1 <= 2 }
      .min { $0.1 < $1.1 }?
      .0
  }

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

  @Flag(name: .shortAndLong, help: "Show the version.")
  var version = false

  func run() throws {
    guard version else { throw CleanExit.helpRequest(self) }
    print("swm version \(Version.current.value)")
  }
}

struct ReloadCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "reload",
    abstract: "Run the configuration file again in the running daemon.",
    discussion: """
      Rules and signals the file registers replace the current ones when the file exits \
      successfully. If it fails, the current rules and signals stay, and settings it changed \
      are restored. Settings the file no longer sets keep their current values.
      """
  )

  @Option(
    name: .shortAndLong,
    help: ArgumentHelp("Path to the configuration file.", valueName: "path"),
    completion: .file()
  )
  var config: String?

  mutating func run() throws {
    try run(
      send: Client.send,
      execute: { path, token in
        try Config.exec(
          path: path,
          environment: token.map { [Client.reloadTokenVariable: $0] } ?? [:]
        )
      },
      processID: getpid(),
      errors: stderr
    )
  }

  func run(
    send: (IPCCommand) -> Client.SendResult,
    execute: (String, String?) throws -> Void,
    processID: pid_t,
    errors: UnsafeMutablePointer<FILE>
  ) throws {
    let path = config ?? StartCommand.defaultConfigPath
    let begin = send(.reload(.begin(processID: processID)))
    guard begin.ok else {
      guard begin.errorCode == .unsupportedCommand else {
        fputs("\(begin.outputMessage)\n", errors)
        throw ExitCode.failure
      }
      fputs("Warning: restart the daemon to make reloads all-or-nothing.\n", errors)
      try clearThenRun(path: path, send: send, execute: execute, errors: errors)
      return
    }

    let token = begin.outputMessage
    do {
      try execute(path, token)
    } catch {
      fputs("Error: \(error)\n", errors)
      let rollback = send(.reload(.rollback(token: token)))
      fputs(
        rollback.ok
          ? "Kept the previous rules, signals, and settings.\n"
          : "\(rollback.outputMessage)\n",
        errors
      )
      throw ExitCode.failure
    }

    let commit = send(.reload(.commit(token: token)))
    guard commit.ok else {
      fputs("\(commit.outputMessage)\n", errors)
      throw ExitCode.failure
    }
  }

  private func clearThenRun(
    path: String,
    send: (IPCCommand) -> Client.SendResult,
    execute: (String, String?) throws -> Void,
    errors: UnsafeMutablePointer<FILE>
  ) throws {
    for command in [IPCCommand.rule(.clear), .signal(.clear)] {
      let result = send(command)
      guard result.ok else {
        fputs("\(result.outputMessage)\n", errors)
        throw ExitCode.failure
      }
    }

    do {
      try execute(path, nil)
    } catch {
      fputs("Error: \(error)\n", errors)
      throw ExitCode.failure
    }
  }
}

struct UnknownSubcommandError: Error, Equatable, CustomStringConvertible {
  let name: String

  let path: String

  let suggestion: String?

  var description: String {
    var message = "Error: Unknown subcommand '\(name)' for '\(path)'."
    if let suggestion {
      message += " Did you mean '\(suggestion)'?"
    }
    return message + "\n  See '\(path) --help' for available subcommands."
  }
}

struct StartCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "start",
    abstract: "Start the window manager daemon.",
    discussion: "Runs when swm is given no subcommand."
  )

  static let defaultConfigPath = FileManager
    .default
    .homeDirectoryForCurrentUser
    .appending(path: ".config/swm/swmrc")
    .path()

  static func isOption(_ argument: String) -> Bool {
    let name = argument.split(separator: "=", maxSplits: 1).first.map(String.init) ?? argument
    return ["-c", "--config", "--log-level"].contains(name)
  }

  @Option(
    name: .shortAndLong,
    help: ArgumentHelp("Path to the configuration file.", valueName: "path"),
    completion: .file()
  )
  var config: String?

  @Option(name: .long, help: "Minimum log level.")
  var logLevel: LogLevel = .info

  mutating func run() {
    MainActor.assumeIsolated {
      runSwm(with: self)
    }
  }
}

extension LogLevel: ExpressibleByArgument {}
