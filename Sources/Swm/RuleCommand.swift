import ArgumentParser
import SwmLib

/// Manage automatic window rules.
struct RuleCommand: ParsableCommand {
  struct Add: RuleIPCCommand {
    static let configuration = CommandConfiguration(
      abstract: "Register a window management rule.",
      discussion:
        "Requires manage=on|off. Optional properties are label, app, title, and bundle-id."
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
