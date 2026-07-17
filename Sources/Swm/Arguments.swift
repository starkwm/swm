import ArgumentParser
import Foundation
import SwmLib

/// Command-line arguments accepted by the swm executable.
struct Arguments: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "swm",
    abstract: "Stark Window Manager for macOS.",
    helpNames: []
  )

  /// Conventional configuration path used when `--config` is omitted.
  static let defaultConfigPath = FileManager
    .default
    .homeDirectoryForCurrentUser
    .appending(path: ".config/swm/swmrc")
    .path()

  /// Show command-line help.
  @Flag(name: .shortAndLong, help: "Show help information.")
  var help = false

  /// Show version information.
  @Flag(name: .shortAndLong, help: "Show version information.")
  var version = false

  /// Path to the user configuration file executed at daemon startup.
  @Option(
    name: .shortAndLong,
    help: ArgumentHelp("Path to the configuration file.", valueName: "path")
  )
  var config: String?

  /// IPC message domain to send instead of starting the daemon.
  @Option(name: .shortAndLong, help: "Send a command to the daemon instead of starting it.")
  var message: MessageDomain?

  /// Minimum runtime log level.
  @Option(name: .long, help: "Minimum log level: debug, info, warn, or error.")
  var logLevel: LogLevel = .info

  /// Arguments passed through to IPC command handlers.
  @Argument(parsing: .captureForPassthrough)
  var args: [String] = []

  /// Execute the parsed daemon or client invocation.
  mutating func run() {
    if help {
      print(Self.helpMessage())
      return
    }

    let arguments = self
    // `ParsableCommand.main()` invokes the root command synchronously from the
    // process main entrypoint, where AppKit runtime setup is permitted.
    MainActor.assumeIsolated {
      runSwm(with: arguments)
    }
  }
}
