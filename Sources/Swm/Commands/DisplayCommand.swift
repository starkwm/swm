import ArgumentParser
import SwmLib

struct DisplayCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "display",
    abstract: "Focus a display.",
    subcommands: [Focus.self]
  )

  struct Focus: DaemonCommand {
    static let configuration = CommandConfiguration(
      abstract: "Focus a display by index, order, recency, mouse position, or direction.",
      discussion: """
        Focuses the frontmost window on the display, or its desktop when it has no windows. \
        next and prev wrap around.

        Examples:
          swm display focus 2
          swm display focus next
          swm display focus recent
          swm display focus right
        """
    )

    @Argument(
      help:
        "One-based display index, next, prev, first, last, recent, mouse, left, right, up, or down.",
      completion: .list([
        "next", "prev", "first", "last", "recent", "mouse", "left", "right", "up", "down",
      ])
    )
    var target: DisplayTarget

    var ipcCommand: IPCCommand { .displayFocus(target) }
  }
}

extension DisplayTarget: ExpressibleByArgument {}
