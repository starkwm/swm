import ArgumentParser
import SwmLib

/// Change global defaults in the running daemon.
struct ConfigCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "config",
    abstract: "Change global layout defaults.",
    subcommands: [
      Layout.self, FocusFollowsMouse.self, MasterRatio.self, MasterPlacement.self,
      PreserveSplit.self,
      WindowGap.self, TopPadding.self, BottomPadding.self, LeftPadding.self, RightPadding.self,
    ]
  )

  struct Layout: ConfigIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Set the default layout.")
    static let command = "layout"

    @Argument(help: "Layout used for all current and future spaces.")
    var layout: LayoutName

    var arguments: [String] { [layout.rawValue] }
  }

  struct FocusFollowsMouse: ConfigIPCCommand {
    static let configuration = CommandConfiguration(
      abstract: "Set how pointer movement focuses windows."
    )
    static let command = "focus-follows-mouse"

    @Argument(help: "Focus mode used for managed windows.")
    var mode: FocusFollowsMouseName

    var arguments: [String] { [mode.rawValue] }
  }

  struct MasterRatio: ConfigIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Set the master-area ratio.")
    static let command = "master-ratio"

    @Argument(help: "Ratio from 0.1 through 0.9.")
    var ratio: Double

    var arguments: [String] { [String(ratio)] }
  }

  struct MasterPlacement: ConfigIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Set the master-area edge.")
    static let command = "master-placement"

    @Argument(help: "Edge used by the master layout.")
    var placement: MasterPlacementName

    var arguments: [String] { [placement.rawValue] }
  }

  struct PreserveSplit: ConfigIPCCommand {
    static let configuration = CommandConfiguration(
      abstract: "Set whether dwindle split directions are retained."
    )
    static let command = "preserve-split"

    @Argument(help: "Enable or disable split preservation.")
    var state: ToggleState

    var arguments: [String] { [state.rawValue] }
  }

  struct WindowGap: ConfigIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Set the window gap.")
    static let command = "window-gap"

    @Argument(help: "Gap in points.")
    var points: Double

    var arguments: [String] { [String(points)] }
  }

  struct TopPadding: ConfigIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Set top padding.")
    static let command = "top-padding"

    @Argument(help: "Padding in points.")
    var points: Double

    var arguments: [String] { [String(points)] }
  }

  struct BottomPadding: ConfigIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Set bottom padding.")
    static let command = "bottom-padding"

    @Argument(help: "Padding in points.")
    var points: Double

    var arguments: [String] { [String(points)] }
  }

  struct LeftPadding: ConfigIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Set left padding.")
    static let command = "left-padding"

    @Argument(help: "Padding in points.")
    var points: Double

    var arguments: [String] { [String(points)] }
  }

  struct RightPadding: ConfigIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Set right padding.")
    static let command = "right-padding"

    @Argument(help: "Padding in points.")
    var points: Double

    var arguments: [String] { [String(points)] }
  }
}

enum MasterPlacementName: String, CaseIterable, ExpressibleByArgument {
  case left, right, top, bottom
}

enum FocusFollowsMouseName: String, CaseIterable, ExpressibleByArgument {
  case off, autofocus, autoraise
}
