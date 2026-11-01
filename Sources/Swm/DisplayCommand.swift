import ArgumentParser
import SwmLib

/// Focus displays.
struct DisplayCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "display",
    abstract: "Focus a display.",
    subcommands: [Focus.self]
  )

  struct Focus: DisplayIPCCommand {
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
    static let command = "--focus"

    @Argument(
      help:
        "One-based display index, next, prev, first, last, recent, mouse, left, right, up, or down.",
      completion: .list(DisplayFocusTarget.keywords)
    )
    var target: DisplayFocusTarget

    var arguments: [String] { [target.argument] }
  }
}

/// Display selector accepted by `swm display focus`.
struct DisplayFocusTarget: ExpressibleByArgument {
  static let keywords = [
    "next", "prev", "first", "last", "recent", "mouse", "left", "right", "up", "down",
  ]

  let argument: String

  init?(argument: String) {
    guard Self.keywords.contains(argument) || (Int(argument).map { $0 > 0 } ?? false) else {
      return nil
    }
    self.argument = argument
  }
}
