import ArgumentParser
import SwmLib

struct WindowCommand: ParsableCommand {
  struct Focus: DaemonCommand {
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

    @Argument(
      help: "left, right, up, down, next, prev, recent, master, or a window ID.",
      completion: .list(["left", "right", "up", "down", "next", "prev", "recent", "master"])
    )
    var target: FocusTarget

    var ipcCommand: IPCCommand {
      switch target {
      case .direction(let direction): .window(.focus(.direction(direction)))
      case .order(let direction): .window(.focusCycle(direction))
      case .master: .window(.focusMaster(.focused))
      case .window(let selection): .window(.focus(.selected(selection)))
      }
    }
  }

  struct Warp: DaemonCommand {
    static let configuration = CommandConfiguration(
      abstract: "Move the mouse cursor to a window or its nearest neighbour in a direction."
    )

    @Argument(
      help:
        "left, right, up, down, recent, or a window ID; defaults to focused. Directions start from the window under the cursor, or focused window.",
      completion: .list(["left", "right", "up", "down", "recent"])
    )
    var target: WarpTarget?

    var ipcCommand: IPCCommand { .window(.warp(target?.target ?? .selected(.focused))) }
  }

  struct Minimize: DaemonCommand {
    static let configuration = CommandConfiguration(
      abstract: "Minimize a window.",
      discussion: """
        Examples:
          swm window minimize
          swm window minimize recent
        """
    )

    @Argument(
      help: "recent or a positive window ID; defaults to focused.",
      completion: .list(["recent"])
    )
    var target: WindowSelection?

    var ipcCommand: IPCCommand { .window(.minimize(target ?? .focused)) }
  }

  struct Unminimize: DaemonCommand {
    static let configuration = CommandConfiguration(
      abstract: "Restore a minimized window.",
      discussion: """
        A minimized window cannot be the focused window, so a target is required.

        Examples:
          swm window unminimize recent
          swm window unminimize 123
        """
    )

    @Argument(
      help: "recent or a positive window ID.",
      completion: .list(["recent"])
    )
    var target: WindowSelection

    var ipcCommand: IPCCommand { .window(.unminimize(target)) }
  }

  struct Move: DaemonCommand, SignedPositionalCommand {
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
    static let valueOptions: Set<String> = ["--window", "--display", "--space"]

    enum Mode {
      case coordinates(x: Int, y: Int)
      case display(WindowDisplayTarget)
      case space(WindowSpaceTarget)
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
      completion: .list(["next", "prev"])
    )
    var display: WindowDisplayTarget?

    @Option(
      help: ArgumentHelp("One-based Space index, next, or prev.", valueName: "target"),
      completion: .list(["next", "prev"])
    )
    var space: WindowSpaceTarget?

    var mode: Mode? {
      switch (x, y, display, space) {
      case (let x?, let y?, nil, nil): .coordinates(x: x, y: y)
      case (nil, nil, let target?, nil): .display(target)
      case (nil, nil, nil, let target?): .space(target)
      default: nil
      }
    }

    var ipcCommand: IPCCommand {
      switch mode {
      case .coordinates(let x, let y):
        let pair = IntPair(x, y)
        return .window(.move(selector.selection, absolute ? .absolute(pair) : .relative(pair)))
      case .display(let target):
        return .window(.display(selector.selection, target))
      case .space(let target):
        return .window(.space(selector.selection, target))
      case nil:
        preconditionFailure("validate() rejects moves without exactly one mode")
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

  struct Resize: DaemonCommand, SignedPositionalCommand {
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
    static let valueOptions: Set<String> = ["--window"]

    @OptionGroup var selector: WindowSelector

    @Flag(help: "Set the size instead of changing it by an offset.")
    var absolute = false

    @Argument(help: "Width or width offset in points.")
    var width: Int

    @Argument(help: "Height or height offset in points.")
    var height: Int

    var ipcCommand: IPCCommand {
      let pair = IntPair(width, height)
      return .window(.resize(selector.selection, absolute ? .absolute(pair) : .relative(pair)))
    }
  }

  struct Grid: DaemonCommand, SignedPositionalCommand {
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

    var ipcCommand: IPCCommand {
      guard
        let grid = WindowGrid(
          rows: rows,
          columns: columns,
          x: x,
          y: y,
          width: width,
          height: height
        )
      else {
        preconditionFailure("validate() rejects non-positive grid dimensions")
      }
      return .window(.grid(selector.selection, grid))
    }

    func validate() throws {
      guard columns > 0, rows > 0 else {
        throw ValidationError("Grid columns and rows must be at least 1.")
      }
    }
  }

  struct Float: DaemonCommand {
    static let configuration = CommandConfiguration(
      abstract: "Enable, disable, or toggle a window floating override."
    )

    @OptionGroup var selector: WindowSelector

    @Argument(
      help:
        "on floats the window; off tiles it; toggle switches its current state. Overrides management rules."
    )
    var state: WindowFloatState

    var ipcCommand: IPCCommand { .window(.layout(selector.selection, state.layoutSelection)) }
  }

  struct Swap: DaemonCommand {
    static let configuration = CommandConfiguration(
      abstract: "Swap a window with a neighbour or the master window.",
      discussion: """
        Examples:
          swm window swap left
          swm window swap next
          swm window swap master
        """
    )

    @OptionGroup var selector: WindowSelector

    @Argument(
      help: "left, right, up, down, next, prev, or master.",
      completion: .list(["left", "right", "up", "down", "next", "prev", "master"])
    )
    var target: SwapTarget

    var ipcCommand: IPCCommand {
      switch target {
      case .direction(let direction): .window(.swap(selector.selection, direction))
      case .order(let direction): .window(.swapCycle(direction))
      case .master: .window(.swapWithMaster(selector.selection))
      }
    }

    func validate() throws {
      if case .order = target, selector.window != nil {
        throw ValidationError("next and prev swap the focused window; omit --window.")
      }
    }
  }

  struct SplitRatio: DaemonCommand, SignedPositionalCommand {
    static let configuration = CommandConfiguration(
      abstract: "Change a dwindle split ratio.",
      discussion: """
        Examples:
          swm window split-ratio 0.5
          swm window split-ratio +0.05
        """
    )
    static let valueOptions: Set<String> = ["--window"]

    @OptionGroup var selector: WindowSelector

    @Argument(help: "Ratio from 0.1 through 0.9, or a signed change such as -0.05.")
    var ratio: SettingChange<Double>

    var ipcCommand: IPCCommand { .window(.splitRatio(selector.selection, ratio.ratioChange)) }

    func validate() throws {
      try ratio.validate(0.1...0.9, name: "Split ratio")
    }
  }

  struct ToggleSplit: DaemonCommand {
    static let configuration = CommandConfiguration(abstract: "Toggle a dwindle split direction.")

    @OptionGroup var selector: WindowSelector

    var ipcCommand: IPCCommand { .window(.toggleSplit(selector.selection)) }
  }

  struct SwapSplit: DaemonCommand {
    static let configuration = CommandConfiguration(abstract: "Exchange dwindle split subtrees.")

    @OptionGroup var selector: WindowSelector

    var ipcCommand: IPCCommand { .window(.swapSplit(selector.selection)) }
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
