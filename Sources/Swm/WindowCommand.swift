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
    static let configuration = CommandConfiguration(abstract: "Minimize a window.")
    static let command = "--minimize"

    @OptionGroup var selector: WindowSelector

    var arguments: [String] { selector.arguments }
  }

  struct Unminimize: WindowIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Restore a minimized window.")
    static let command = "--unminimize"

    @OptionGroup var selector: WindowSelector

    var arguments: [String] { selector.arguments }
  }

  struct Move: WindowGeometryCommand {
    static let configuration = CommandConfiguration(
      abstract: "Move a window.",
      discussion: """
        Move by an offset in points, set the top-left corner with --absolute, or transfer
        to a display or Space. Choose exactly one mode: x y, --display, or --space.

        Coordinate moves reject tiled windows; float them with `swm window float on` first.
        Transfers keep the current Space active.

        Examples:
          swm window move --absolute 0 25
          swm window move -20 0
          swm window move --display next
          swm window move --space 3
          swm window move --window 123 --display 2
        """
    )
    static let command = "--move"

    @OptionGroup var selector: WindowSelector

    @Flag(help: "Set the top-left corner instead of moving by an offset.")
    var absolute = false

    @Argument(help: "Horizontal position or offset in points.")
    var x: Int?

    @Argument(help: "Vertical position or offset in points.")
    var y: Int?

    @Option(
      help: "One-based display index, next, prev, or previous.",
      completion: .list(["next", "prev", "previous"])
    )
    var display: WindowTransferTarget?

    @Option(
      help: "One-based Space index, next, prev, or previous.",
      completion: .list(["next", "prev", "previous"])
    )
    var space: WindowTransferTarget?

    var commandArguments: [String] {
      if let display { return ["--display"] + selector.arguments + [display.value] }
      if let space { return ["--space"] + selector.arguments + [space.value] }
      guard let x, let y else { return [] }
      return [Self.command] + selector.arguments + ["\(absolute ? "abs" : "rel"):\(x):\(y)"]
    }

    func validate() throws {
      guard (x == nil) == (y == nil) else {
        throw ValidationError("Coordinate mode requires both x and y.")
      }
      let modes = [x != nil, display != nil, space != nil].filter { $0 }.count
      guard modes == 1 else {
        throw ValidationError(
          "Choose exactly one mode: x y, --display <target>, or --space <target>."
        )
      }
      guard !absolute || x != nil else {
        throw ValidationError("--absolute is valid only with x y coordinates.")
      }
    }
  }

  struct Resize: WindowGeometryCommand {
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

  struct Grid: WindowIPCCommand {
    static let configuration = CommandConfiguration(
      abstract: "Place a window on a grid.",
      discussion: """
        x, y, width, and height are measured in grid cells from the top left.

        Tiled windows are rejected; float them with `swm window float on` first.

        Examples:
          swm window grid 2:1:0:0:1:1   # left half
          swm window grid 2:1:1:0:1:1   # right half
          swm window grid 1:1:0:0:1:1   # whole display
        """
    )
    static let command = "--grid"

    @OptionGroup var selector: WindowSelector

    @Argument(help: "Grid in the form columns:rows:x:y:width:height.")
    var grid: String

    var arguments: [String] { selector.arguments + [grid] }
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

  struct SplitRatio: WindowIPCCommand, SettingChangeCommand {
    static let configuration = CommandConfiguration(
      abstract: "Change a dwindle split ratio.",
      discussion: """
        Examples:
          swm window split-ratio 0.5
          swm window split-ratio +0.05
        """
    )
    static let command = "--split-ratio"

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

/// Window to focus, relative to the focused window or by identity.
enum FocusTarget: Equatable, ExpressibleByArgument {
  case direction(CardinalDirectionName)
  case order(CycleDirectionName)
  case master
  case window(String)

  init?(argument: String) {
    if let direction = CardinalDirectionName(rawValue: argument) {
      self = .direction(direction)
    } else if let direction = CycleDirectionName(rawValue: argument) {
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
  case direction(CardinalDirectionName)
  case order(CycleDirectionName)
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
      CardinalDirectionName(rawValue: argument) != nil
        || argument == "recent" || UInt32(argument).map({ $0 > 0 }) == true
    else { return nil }
    value = argument
  }
}

enum CycleDirectionName: String, CaseIterable, ExpressibleByArgument {
  case next, prev
}

enum CardinalDirectionName: String, CaseIterable, ExpressibleByArgument {
  case left, right, up, down
}

/// Shared destination syntax for window transfers; resolution stays in the daemon.
struct WindowTransferTarget: ExpressibleByArgument {
  let value: String

  init?(argument: String) {
    guard
      ["next", "prev", "previous"].contains(argument)
        || Int(argument).map({ $0 > 0 }) == true
    else { return nil }
    value = argument
  }
}
