import ArgumentParser
import SwmLib

/// Focus, move, resize, and arrange windows.
struct WindowCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "window",
    abstract: "Focus, move, resize, and arrange windows.",
    subcommands: [
      Focus.self, Minimize.self, Unminimize.self, Move.self, Resize.self, Grid.self, Display.self,
      Layout.self, Cycle.self, Swap.self, SwapCycle.self, SwapWithMaster.self, FocusMaster.self,
      SplitRatio.self, ToggleSplit.self, SwapSplit.self,
    ]
  )

  struct Focus: WindowIPCCommand {
    static let configuration = CommandConfiguration(
      abstract: "Focus a window or the nearest window in a direction."
    )
    static let command = "--focus"

    @Option(name: .shortAndLong, help: "Window ID or recent.")
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

  struct Minimize: WindowIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Minimize a window.")
    static let command = "--minimize"

    @Option(name: .shortAndLong, help: "Window ID or recent; defaults to focused.")
    var window: String?

    var arguments: [String] { window.map { [$0] } ?? [] }
  }

  struct Unminimize: WindowIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Restore a minimized window.")
    static let command = "--unminimize"

    @Option(name: .shortAndLong, help: "Window ID or recent; defaults to focused.")
    var window: String?

    var arguments: [String] { window.map { [$0] } ?? [] }
  }

  struct Move: WindowIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Move a window.")
    static let command = "--move"

    @Option(name: .shortAndLong, help: "Window ID or recent; defaults to focused.")
    var window: String?

    @Argument(help: "Position in the form abs|rel:<x>:<y>.")
    var position: String

    var arguments: [String] { [window, position].compactMap { $0 } }
  }

  struct Resize: WindowIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Resize a window.")
    static let command = "--resize"

    @Option(name: .shortAndLong, help: "Window ID or recent; defaults to focused.")
    var window: String?

    @Argument(help: "Size in the form abs|rel:<width>:<height>.")
    var size: String

    var arguments: [String] { [window, size].compactMap { $0 } }
  }

  struct Grid: WindowIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Place a window on a grid.")
    static let command = "--grid"

    @Option(name: .shortAndLong, help: "Window ID or recent; defaults to focused.")
    var window: String?

    @Argument(help: "Grid in the form columns:rows:x:y:width:height.")
    var grid: String

    var arguments: [String] { [window, grid].compactMap { $0 } }
  }

  struct Display: WindowIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Move a window to another display.")
    static let command = "--display"

    @Option(name: .shortAndLong, help: "Window ID or recent; defaults to focused.")
    var window: String?

    @Argument(help: "One-based display index, next, or prev.")
    var display: String

    var arguments: [String] { [window, display].compactMap { $0 } }
  }

  struct Layout: WindowIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Change a window tiling state.")
    static let command = "--layout"

    @Option(name: .shortAndLong, help: "Window ID or recent; defaults to focused.")
    var window: String?

    @Argument(help: "New tiling state.")
    var layout: WindowLayoutName

    var arguments: [String] { [window, layout.rawValue].compactMap { $0 } }
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

    @Option(name: .shortAndLong, help: "Window ID or recent; defaults to focused.")
    var window: String?

    @Option(name: .shortAndLong, help: "Direction of the neighbouring window.")
    var direction: CardinalDirectionName

    var arguments: [String] { [window, direction.rawValue].compactMap { $0 } }
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

    @Option(name: .shortAndLong, help: "Window ID or recent; defaults to focused.")
    var window: String?

    var arguments: [String] { window.map { [$0] } ?? [] }
  }

  struct FocusMaster: WindowIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Focus the master window.")
    static let command = "--focus-master"

    @Option(name: .shortAndLong, help: "Window ID or recent; defaults to focused.")
    var window: String?

    var arguments: [String] { window.map { [$0] } ?? [] }
  }

  struct SplitRatio: WindowIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Change a dwindle split ratio.")
    static let command = "--split-ratio"

    @Option(name: .shortAndLong, help: "Window ID or recent; defaults to focused.")
    var window: String?

    @Argument(help: "Change in the form abs:<ratio> or rel:<ratio>.")
    var change: String

    var arguments: [String] { [window, change].compactMap { $0 } }
  }

  struct ToggleSplit: WindowIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Toggle a dwindle split direction.")
    static let command = "--toggle-split"

    @Option(name: .shortAndLong, help: "Window ID or recent; defaults to focused.")
    var window: String?

    var arguments: [String] { window.map { [$0] } ?? [] }
  }

  struct SwapSplit: WindowIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Exchange dwindle split subtrees.")
    static let command = "--swap-split"

    @Option(name: .shortAndLong, help: "Window ID or recent; defaults to focused.")
    var window: String?

    var arguments: [String] { window.map { [$0] } ?? [] }
  }
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
