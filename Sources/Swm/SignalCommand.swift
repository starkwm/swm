import ArgumentParser
import SwmLib

/// Manage commands triggered by daemon events.
struct SignalCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "signal",
    abstract: "Manage event signals.",
    subcommands: [Add.self, List.self, Remove.self]
  )

  struct Add: SignalIPCCommand {
    static let configuration = CommandConfiguration(
      abstract: "Register a command for a matching event.",
      discussion:
        "Requires event=<name> and action=<shell command>. Optional filters are label, app, title, and active."
    )
    static let command = "--add"

    @Argument(help: "Signal properties written as key=value or key!=value.")
    var properties: [String]

    var arguments: [String] { properties }
  }

  struct List: SignalIPCCommand {
    static let configuration = CommandConfiguration(abstract: "List registered signals.")
    static let command = "--list"
  }

  struct Remove: SignalIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Remove a registered signal.")
    static let command = "--remove"

    @Argument(help: "Signal index or label.")
    var signal: String

    var arguments: [String] { [signal] }
  }
}
