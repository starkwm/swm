import ArgumentParser
import SwmLib

struct RuleCommand: ParsableCommand {
  struct Add: DaemonCommand {
    static let configuration = CommandConfiguration(
      abstract: "Register a window management rule.",
      discussion: """
        Requires at least one of manage=on|off, grid=columns:rows:x:y:width:height, \
        display=index|uuid, or space=index. A rule sets display or space, not both. Optional filters are app, title, and bundle-id; write key!=value to \
        require no match, as in bundle-id!=com.apple.finder. label names the rule.

        Examples:
          swm rule add label=finder bundle-id=com.apple.finder manage=off
          swm rule add app='^Safari$' grid=2:1:1:0:1:1 display=2
          swm rule add app='^Slack$' space=3
        """
    )

    @Argument(help: "Rule properties written as key=value or key!=value.")
    var properties: [String]

    var ipcCommand: IPCCommand { .rule(.add(properties)) }
  }

  struct List: DaemonCommand {
    static let configuration = CommandConfiguration(abstract: "List registered rules.")

    var ipcCommand: IPCCommand { .rule(.list) }
  }

  struct Clear: DaemonCommand {
    static let configuration = CommandConfiguration(abstract: "Remove every registered rule.")

    var ipcCommand: IPCCommand { .rule(.clear) }
  }

  struct Remove: DaemonCommand {
    static let configuration = CommandConfiguration(abstract: "Remove a registered rule.")

    @Argument(help: "Rule index or label.")
    var rule: String

    var ipcCommand: IPCCommand { .rule(.remove(rule)) }
  }

  static let configuration = CommandConfiguration(
    commandName: "rule",
    abstract: "Manage window rules.",
    subcommands: [Add.self, List.self, Remove.self, Clear.self]
  )
}
