import ArgumentParser
import SwmLib

struct SignalCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "signal",
    abstract: "Manage event signals.",
    subcommands: [Add.self, List.self, Remove.self, Clear.self]
  )

  struct Add: DaemonCommand {
    static let configuration = CommandConfiguration(
      abstract: "Register a command for a matching event.",
      discussion: """
        Requires event=<name> and action=<shell command>. Optional filters are label, app, \
        title, and active=on|off.

        Examples:
          swm signal add event=window-focused action='echo "$SWM_WINDOW_ID"'
          swm signal add event=window-created app='^Safari$' action='swm window warp'
        """
    )

    @Argument(help: "Signal properties written as key=value or key!=value.")
    var properties: [String]

    var ipcCommand: IPCCommand { .signal(.add(properties)) }
  }

  struct List: DaemonCommand {
    static let configuration = CommandConfiguration(abstract: "List registered signals.")

    var ipcCommand: IPCCommand { .signal(.list) }
  }

  struct Clear: DaemonCommand {
    static let configuration = CommandConfiguration(abstract: "Remove every registered signal.")

    var ipcCommand: IPCCommand { .signal(.clear) }
  }

  struct Remove: DaemonCommand {
    static let configuration = CommandConfiguration(abstract: "Remove a registered signal.")

    @Argument(help: "Signal index or label.")
    var signal: String

    var ipcCommand: IPCCommand { .signal(.remove(signal)) }
  }
}
