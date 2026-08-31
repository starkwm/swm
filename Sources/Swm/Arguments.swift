import ArgumentParser
import Foundation
import SwmLib

/// Root command for the swm executable.
struct Arguments: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "swm",
    abstract: "Stark Window Manager for macOS.",
    groupedSubcommands: [
      CommandGroup(name: "DAEMON", subcommands: [StartCommand.self]),
      CommandGroup(
        name: "WINDOW",
        subcommands: [SpaceCommand.self, WindowCommand.self]
      ),
      CommandGroup(
        name: "OTHER",
        subcommands: [ConfigCommand.self, QueryCommand.self, SignalCommand.self]
      ),
    ],
    defaultSubcommand: StartCommand.self
  )

  /// Show version information.
  @Flag(name: .long, help: "Show the version.")
  var version = false
}

/// Start the window manager daemon.
struct StartCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "start",
    abstract: "Start the window manager daemon."
  )

  /// Conventional configuration path used when `--config` is omitted.
  static let defaultConfigPath = FileManager
    .default
    .homeDirectoryForCurrentUser
    .appending(path: ".config/swm/swmrc")
    .path()

  /// Path to the user configuration file executed at daemon startup.
  @Option(
    name: .shortAndLong,
    help: ArgumentHelp("Path to the configuration file.", valueName: "path")
  )
  var config: String?

  /// Minimum runtime log level.
  @Option(name: .long, help: "Minimum log level: debug, info, warn, or error.")
  var logLevel: LogLevel = .info

  /// Start the daemon using the parsed options.
  mutating func run() {
    MainActor.assumeIsolated {
      runSwm(with: self)
    }
  }
}
