import ArgumentParser
import SwmLib

/// Focus, move, resize, arrange windows, and position the mouse cursor.
struct WindowCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "window",
    abstract: "Focus, move, resize, and arrange windows.",
    subcommands: [
      Focus.self, Warp.self, Minimize.self, Unminimize.self, Move.self, Resize.self, Grid.self,
      Display.self,
      Space.self,
      Layout.self, Cycle.self, Swap.self, SwapCycle.self, SwapWithMaster.self, FocusMaster.self,
      SplitRatio.self, ToggleSplit.self, SwapSplit.self,
    ]
  )

  struct Focus: WindowIPCCommand {
    static let configuration = CommandConfiguration(
      abstract: "Focus a window or the nearest window in a direction."
    )
    static let command = "--focus"

    @Option(name: .shortAndLong, help: "Window ID or recent.", completion: .list(["recent"]))
    var window: String?

    @Option(name: .shortAndLong, help: "Direction of the neighbouring window.")
    var direction: CardinalDirectionName?

    var arguments: [String] { [window, direction?.rawValue].compactMap { $0 } }

    func validate() throws {
      if window != nil, direction != nil {
        throw ValidationError("Specify either --window or --direction, not both.")
      }
    }
  }

  struct Warp: WindowIPCCommand {
    static let configuration = CommandConfiguration(
      abstract: "Move the mouse cursor to a window or its nearest neighbour in a direction."
    )
    static let command = "--warp"

    @OptionGroup var selector: WindowSelector

    @Option(
      name: .shortAndLong,
      help: "Direction from the window under the cursor, or focused window."
    )
    var direction: CardinalDirectionName?

    var arguments: [String] { selector.arguments + [direction?.rawValue].compactMap { $0 } }

    func validate() throws {
      if selector.window != nil, direction != nil {
        throw ValidationError("Specify either --window or --direction, not both.")
      }
    }
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

  struct Move: WindowIPCCommand {
    static let configuration = CommandConfiguration(
      abstract: "Move a window.",
      discussion: """
        abs sets the top-left corner; rel moves by an offset in points.

        Examples:
          swm window move abs:0:25
          swm window move rel:-20:0
        """
    )
    static let command = "--move"

    @OptionGroup var selector: WindowSelector

    @Argument(help: "Position in the form abs|rel:<x>:<y>.")
    var position: String

    var arguments: [String] { selector.arguments + [position] }
  }

  struct Resize: WindowIPCCommand {
    static let configuration = CommandConfiguration(
      abstract: "Resize a window.",
      discussion: """
        abs sets the size; rel changes it by an offset in points.

        Examples:
          swm window resize abs:1200:800
          swm window resize rel:40:0
        """
    )
    static let command = "--resize"

    @OptionGroup var selector: WindowSelector

    @Argument(help: "Size in the form abs|rel:<width>:<height>.")
    var size: String

    var arguments: [String] { selector.arguments + [size] }
  }

  struct Grid: WindowIPCCommand {
    static let configuration = CommandConfiguration(
      abstract: "Place a window on a grid.",
      discussion: """
        x, y, width, and height are measured in grid cells from the top left.

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

  struct Display: WindowIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Move a window to another display.")
    static let command = "--display"

    @OptionGroup var selector: WindowSelector

    @Argument(
      help: "One-based display index, next, or prev.",
      completion: .list(["next", "prev"])
    )
    var display: String

    var arguments: [String] { selector.arguments + [display] }
  }

  struct Space: WindowIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Move a window to another Space.")
    static let command = "--space"

    @OptionGroup var selector: WindowSelector

    @Argument(help: "One-based Space index, next, or prev.", completion: .list(["next", "prev"]))
    var space: String

    var arguments: [String] { selector.arguments + [space] }
  }

  struct Layout: WindowIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Change a window tiling state.")
    static let command = "--layout"

    @OptionGroup var selector: WindowSelector

    @Argument(help: "New tiling state.")
    var layout: WindowLayoutName

    var arguments: [String] { selector.arguments + [layout.rawValue] }
  }

  struct Cycle: WindowIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Focus a window in layout order.")
    static let command = "--cycle"

    @Option(name: .shortAndLong, help: "Cycle direction.")
    var direction: CycleDirectionName

    var arguments: [String] { [direction.rawValue] }
  }

  struct Swap: WindowIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Swap a window in a direction.")
    static let command = "--swap"

    @OptionGroup var selector: WindowSelector

    @Option(name: .shortAndLong, help: "Direction of the neighbouring window.")
    var direction: CardinalDirectionName

    var arguments: [String] { selector.arguments + [direction.rawValue] }
  }

  struct SwapCycle: WindowIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Swap a window in layout order.")
    static let command = "--swap-cycle"

    @Option(name: .shortAndLong, help: "Cycle direction.")
    var direction: CycleDirectionName

    var arguments: [String] { [direction.rawValue] }
  }

  struct SwapWithMaster: WindowIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Promote a window to master.")
    static let command = "--swap-with-master"

    @OptionGroup var selector: WindowSelector

    var arguments: [String] { selector.arguments }
  }

  struct FocusMaster: WindowIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Focus the master window.")
    static let command = "--focus-master"

    @OptionGroup var selector: WindowSelector

    var arguments: [String] { selector.arguments }
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
}

/// Optional window selector for commands that default to the focused window.
struct WindowSelector: ParsableArguments {
  @Option(
    name: .shortAndLong,
    help: "Window ID or recent; defaults to focused.",
    completion: .list(["recent"])
  )
  var window: String?

  /// IPC arguments selecting the window, or none for the focused window.
  var arguments: [String] { window.map { [$0] } ?? [] }
}

enum WindowLayoutName: String, CaseIterable, ExpressibleByArgument {
  case float, tile, toggle
}

enum CycleDirectionName: String, CaseIterable, ExpressibleByArgument {
  case next, prev
}

enum CardinalDirectionName: String, CaseIterable, ExpressibleByArgument {
  case left, right, up, down
}
