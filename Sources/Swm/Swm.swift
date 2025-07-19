import AppKit
import ArgumentParser
import SwmLib

struct Swm: ParsableArguments {
  @Flag(name: .shortAndLong)
  var help = false

  @Flag(name: .shortAndLong, help: "Show version information.")
  var version = false

  @Option(name: .shortAndLong, help: ArgumentHelp("Path to the configuration file.", valueName: "path"))
  var config: String = FileManager
    .default
    .homeDirectoryForCurrentUser
    .appending(path: ".config/swm/swmrc")
    .path()

  @Option(name: .shortAndLong)
  var message: MessageDomain?

  @Argument(parsing: .captureForPassthrough)
  var args: [String] = []
}
