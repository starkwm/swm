import ArgumentParser
import SwmLib

/// Focus, move, resize, arrange windows, and position the mouse cursor.
struct WindowCommand: ParsableCommand {
  struct Focus: WindowIPCCommand {
    static let configuration = CommandConfiguration(
      abstract: "Focus a neighbouring, recent, master, or specific window.",
      discussion: """
        Examples:
          swm window focus left
          swm window focus next
          swm window focus recent
          swm window focus master
        """
    )
    static let command = "--focus"

    @Argument(
      help: "left, right, up, down, next, prev, recent, master, or a window ID.",
      completion: .list(["left", "right", "up", "down", "next", "prev", "recent", "master"])
    )
    var target: FocusTarget

    var commandArguments: [String] {
      switch target {
      case .direction(let direction): ["--focus", direction.rawValue]
      case .order(let direction): ["--cycle", direction.rawValue]
      case .master: ["--focus-master"]
      case .window(let selector): ["--focus", selector]
      }
    }
  }

  struct Warp: WindowIPCCommand {
    static let configuration = CommandConfiguration(
      abstract: "Move the mouse cursor to a window or its nearest neighbour in a direction."
    )
    static let command = "--warp"

    @Argument(
      help:
        "left, right, up, down, recent, or a window ID; defaults to focused. Directions start from the window under the cursor, or focused window.",
      completion: .list(["left", "right", "up", "down", "recent"])
    )
    var target: WarpTarget?

    var arguments: [String] { target.map { [$0.value] } ?? [] }
  }

  struct Minimize: WindowIPCCommand {
    static let configuration = CommandConfiguration(
      abstract: "Minimize a window.",
      discussion: """
        Examples:
          swm window minimize
          swm window minimize recent
        """
    )
    static let command = "--minimize"

    @Argument(
      help: "recent or a positive window ID; defaults to focused.",
      completion: .list(["recent"])
    )
    var target: WindowIdentityTarget?

    var arguments: [String] { target.map { [$0.value] } ?? [] }
  }

  struct Unminimize: WindowIPCCommand {
    static let configuration = CommandConfiguration(
      abstract: "Restore a minimized window.",
      discussion: """
        A minimized window cannot be the focused window, so a target is required.

        Examples:
          swm window unminimize recent
          swm window unminimize 123
        """
    )
    static let command = "--unminimize"

    @Argument(
      help: "recent or a positive window ID.",
      completion: .list(["recent"])
    )
    var target: WindowIdentityTarget

    var arguments: [String] { [target.value] }
  }

  struct Move: WindowIPCCommand, SignedPositionalCommand {
    static let configuration = CommandConfiguration(
      abstract: "Move a window.",
      usage: """
        swm window move [--window <window>] [--absolute] <x> <y>
        swm window move [--window <window>] --display <target>
        swm window move [--window <window>] --space <target>
        """,
      discussion: """
        Choose one mode: x y, --display <target>, or --space <target>.

        Coordinates move the window by an offset in points. Use --absolute only with
        coordinates to set the top-left corner. Float tiled windows with
        `swm window float on` before moving them by coordinates.

        Moving to a display or Space keeps the current Space active.

        Examples:
          swm window move --absolute 0 25
          swm window move -20 0
          swm window move --display next
          swm window move --space 3
          swm window move --window 123 --display 2
        """
    )
    static let command = "--move"
    static let valueOptions: Set<String> = ["--window", "--display", "--space"]

    /// The single way a move was requested.
    enum Mode {
      case coordinates(x: Int, y: Int)
      case display(WindowTransferTarget)
      case space(WindowTransferTarget)
    }

    @OptionGroup var selector: WindowSelector

    @Flag(help: "Set the top-left corner instead of moving by an offset.")
    var absolute = false

    @Argument(help: "Horizontal position or offset in points.")
    var x: Int?

    @Argument(help: "Vertical position or offset in points.")
    var y: Int?

    @Option(
      help: ArgumentHelp(
        "One-based display index, next, or prev.",
        valueName: "target"
      ),
      completion: .list(WindowTransferTarget.keywords)
    )
    var display: WindowTransferTarget?

    @Option(
      help: ArgumentHelp("One-based Space index, next, or prev.", valueName: "target"),
      completion: .list(WindowTransferTarget.keywords)
    )
    var space: WindowTransferTarget?

    /// The requested mode, or nil when modes conflict or coordinates are incomplete.
    var mode: Mode? {
      switch (x, y, display, space) {
      case (let x?, let y?, nil, nil): .coordinates(x: x, y: y)
      case (nil, nil, let target?, nil): .display(target)
      case (nil, nil, nil, let target?): .space(target)
      default: nil
      }
    }

    var arguments: [String] {
      switch mode {
      case .coordinates(let x, let y):
        selector.arguments + ["\(absolute ? "abs" : "rel"):\(x):\(y)"]
      case .display(let target), .space(let target):
        selector.arguments + [target.value]
      case nil:
        preconditionFailure("validate() rejects moves without exactly one mode")
      }
    }

    var commandArguments: [String] {
      switch mode {
      case .coordinates: [Self.command] + arguments
      case .display: ["--display"] + arguments
      case .space: ["--space"] + arguments
      case nil: preconditionFailure("validate() rejects moves without exactly one mode")
      }
    }

    func validate() throws {
      let modes = [x != nil, display != nil, space != nil].filter { $0 }.count
      guard modes == 1 else {
        throw ValidationError(
          "Choose exactly one mode: x y, --display <target>, or --space <target>."
        )
      }
      guard (x == nil) == (y == nil) else {
        throw ValidationError("Coordinate mode requires both x and y.")
      }
      guard !absolute || x != nil else {
        throw ValidationError("--absolute is valid only with x y coordinates.")
      }
    }
  }

  struct Resize: WindowIPCCommand, SignedPositionalCommand {
    static let configuration = CommandConfiguration(
      abstract: "Resize a window.",
      discussion: """
        Changes the size by an offset in points by default. Use --absolute to set the size.

        Tiled windows are rejected; float them with `swm window float on` first.

        Examples:
          swm window resize --absolute 1200 800
          swm window resize 40 0
        """
    )
    static let command = "--resize"
    static let valueOptions: Set<String> = ["--window"]

    @OptionGroup var selector: WindowSelector

    @Flag(help: "Set the size instead of changing it by an offset.")
    var absolute = false

    @Argument(help: "Width or width offset in points.")
    var width: Int

    @Argument(help: "Height or height offset in points.")
    var height: Int

    var arguments: [String] {
      selector.arguments + ["\(absolute ? "abs" : "rel"):\(width):\(height)"]
    }
  }

  struct Grid: WindowIPCCommand, SignedPositionalCommand {
    static let configuration = CommandConfiguration(
      abstract: "Place a window on a grid.",
      discussion: """
        Columns and rows must be at least 1. x and y count cells from 0 at the top
        left. swm clamps x and y into the grid, and clamps width and height to
        between 1 and the cells left on that axis.

        Tiled windows are rejected; float them with `swm window float on` first.

        Examples:
          swm window grid 2 1 0 0 1 1   # left half
          swm window grid 2 1 1 0 1 1   # right half
          swm window grid 1 1 0 0 1 1   # whole display
        """
    )
    static let command = "--grid"
    static let valueOptions: Set<String> = ["--window"]

    @OptionGroup var selector: WindowSelector

    @Argument(help: "Number of columns.")
    var columns: Int

    @Argument(help: "Number of rows.")
    var rows: Int

    @Argument(help: "Column to start at, from 0.")
    var x: Int

    @Argument(help: "Row to start at, from 0.")
    var y: Int

    @Argument(help: "Columns to span.")
    var width: Int

    @Argument(help: "Rows to span.")
    var height: Int

    var arguments: [String] {
      selector.arguments + ["\(columns):\(rows):\(x):\(y):\(width):\(height)"]
    }

    func validate() throws {
      guard columns > 0, rows > 0 else {
        throw ValidationError("Grid columns and rows must be at least 1.")
      }
    }
  }

  struct Float: WindowIPCCommand {
    static let configuration = CommandConfiguration(
      abstract: "Enable, disable, or toggle a window floating override."
    )
    static let command = "--layout"

    @OptionGroup var selector: WindowSelector

    @Argument(
      help:
        "on floats the window; off tiles it; toggle switches its current state. Overrides management rules."
    )
    var state: WindowFloatState

    var arguments: [String] { selector.arguments + [state.layoutValue] }
  }

  struct Swap: WindowIPCCommand {
    static let configuration = CommandConfiguration(
      abstract: "Swap a window with a neighbour or the master window.",
      discussion: """
        Examples:
          swm window swap left
          swm window swap next
          swm window swap master
        """
    )
    static let command = "--swap"

    @OptionGroup var selector: WindowSelector

    @Argument(
      help: "left, right, up, down, next, prev, or master.",
      completion: .list(["left", "right", "up", "down", "next", "prev", "master"])
    )
    var target: SwapTarget

    var commandArguments: [String] {
      switch target {
      case .direction(let direction): ["--swap"] + selector.arguments + [direction.rawValue]
      case .order(let direction): ["--swap-cycle", direction.rawValue]
      case .master: ["--swap-with-master"] + selector.arguments
      }
    }

    func validate() throws {
      if case .order = target, selector.window != nil {
        throw ValidationError("next and prev swap the focused window; omit --window.")
      }
    }
  }

  struct SplitRatio: WindowIPCCommand, SignedPositionalCommand {
    static let configuration = CommandConfiguration(
      abstract: "Change a dwindle split ratio.",
      discussion: """
        Examples:
          swm window split-ratio 0.5
          swm window split-ratio +0.05
        """
    )
    static let command = "--split-ratio"
    static let valueOptions: Set<String> = ["--window"]

    @OptionGroup var selector: WindowSelector

    @Argument(help: "Ratio from 0.1 through 0.9, or a signed change such as -0.05.")
    var ratio: SettingChange<Double>

    var arguments: [String] { selector.arguments + [ratio.ipcValue] }

    func validate() throws {
      try ratio.validate(0.1...0.9, name: "Split ratio")
    }
  }

  struct ToggleSplit: WindowIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Toggle a dwindle split direction.")
    static let command = "--toggle-split"

    @OptionGroup var selector: WindowSelector

    var arguments: [String] { selector.arguments }
  }

  struct SwapSplit: WindowIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Exchange dwindle split subtrees.")
    static let command = "--swap-split"

    @OptionGroup var selector: WindowSelector

    var arguments: [String] { selector.arguments }
  }

  static let configuration = CommandConfiguration(
    commandName: "window",
    abstract: "Focus, move, resize, and arrange windows.",
    subcommands: [
      Focus.self, Warp.self, Minimize.self, Unminimize.self, Move.self, Resize.self, Grid.self,
      Float.self, Swap.self, SplitRatio.self, ToggleSplit.self, SwapSplit.self,
    ]
  )
}

/// Optional window selector for commands that default to the focused window.
struct WindowSelector: ParsableArguments {
  @Option(
    name: .long,
    help: "Window ID or recent; defaults to focused.",
    completion: .list(["recent"])
  )
  var window: String?

  /// IPC arguments selecting the window, or none for the focused window.
  var arguments: [String] { window.map { [$0] } ?? [] }
}

/// A specific window or the previously focused window.
struct WindowIdentityTarget: ExpressibleByArgument {
  let value: String

  init?(argument: String) {
    guard argument == "recent" || UInt32(argument).map({ $0 > 0 }) == true else { return nil }
    value = argument
  }
}

/// Window to focus, relative to the focused window or by identity.
enum FocusTarget: Equatable, ExpressibleByArgument {
  case direction(CardinalDirection)
  case order(CycleDirection)
  case master
  case window(String)

  init?(argument: String) {
    if let direction = CardinalDirection(rawValue: argument) {
      self = .direction(direction)
    } else if let direction = CycleDirection(rawValue: argument) {
      self = .order(direction)
    } else if argument == "master" {
      self = .master
    } else if argument == "recent" || UInt32(argument) != nil {
      self = .window(argument)
    } else {
      return nil
    }
  }
}

/// Window to swap the selected window with.
enum SwapTarget: Equatable, ExpressibleByArgument {
  case direction(CardinalDirection)
  case order(CycleDirection)
  case master

  init?(argument: String) {
    switch FocusTarget(argument: argument) {
    case .direction(let direction): self = .direction(direction)
    case .order(let direction): self = .order(direction)
    case .master: self = .master
    case .window, nil: return nil
    }
  }
}

enum WindowFloatState: String, CaseIterable, ExpressibleByArgument {
  case on, off, toggle

  var layoutValue: String {
    switch self {
    case .on: "float"
    case .off: "tile"
    case .toggle: "toggle"
    }
  }
}

/// A cursor destination without focus-only navigation targets.
struct WarpTarget: ExpressibleByArgument {
  let value: String

  init?(argument: String) {
    guard
      CardinalDirection(rawValue: argument) != nil
        || argument == "recent" || UInt32(argument).map({ $0 > 0 }) == true
    else { return nil }
    value = argument
  }
}

/// Shared destination syntax for window transfers; resolution stays in the daemon.
struct WindowTransferTarget: ExpressibleByArgument {
  static let keywords = ["next", "prev"]

  let value: String

  init?(argument: String) {
    guard
      Self.keywords.contains(argument)
        || Int(argument).map({ $0 > 0 }) == true
    else { return nil }
    value = argument
  }
}
