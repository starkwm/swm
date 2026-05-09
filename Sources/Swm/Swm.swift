import AppKit
import ArgumentParser
import SwmLib

/// Command-line arguments accepted by the swm executable.
struct Swm: ParsableArguments {
  /// Show command-line help.
  @Flag(name: .shortAndLong)
  var help = false

  /// Show version information.
  @Flag(name: .shortAndLong, help: "Show version information.")
  var version = false

  /// Path to the user configuration file executed at daemon startup.
  @Option(
    name: .shortAndLong,
    help: ArgumentHelp("Path to the configuration file.", valueName: "path")
  )
  var config: String = FileManager
    .default
    .homeDirectoryForCurrentUser
    .appending(path: ".config/swm/swmrc")
    .path()

  /// IPC message domain to send instead of starting the daemon.
  @Option(name: .shortAndLong)
  var message: MessageDomain?

  /// Minimum runtime log level.
  @Option(name: .long, help: "Minimum log level: debug, info, warn, or error.")
  var logLevel: LogLevel = .info

  /// Arguments passed through to IPC command handlers.
  @Argument(parsing: .captureForPassthrough)
  var args: [String] = []
}
