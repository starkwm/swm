import ArgumentParser
import SwmLib

/// Manage automatic window rules.
struct RuleCommand: ParsableCommand {
  struct Add: RuleIPCCommand {
    static let configuration = CommandConfiguration(
      abstract: "Register a window management rule.",
      discussion:
        "Requires at least one of manage=on|off, grid=columns:rows:x:y:width:height, or display=index|uuid. Optional filters are app, title, and bundle-id; label names the rule."
    )
    static let command = "--add"

    @Argument(help: "Rule properties written as key=value or key!=value.")
    var properties: [String]

    var arguments: [String] { properties }
  }

  struct List: RuleIPCCommand {
    static let configuration = CommandConfiguration(abstract: "List registered rules.")
    static let command = "--list"
  }

  struct Remove: RuleIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Remove a registered rule.")
    static let command = "--remove"

    @Argument(help: "Rule index or label.")
    var rule: String

    var arguments: [String] { [rule] }
  }
  static let configuration = CommandConfiguration(
    commandName: "rule",
    abstract: "Manage window rules.",
    subcommands: [Add.self, List.self, Remove.self]
  )
}
