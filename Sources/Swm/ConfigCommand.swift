import ArgumentParser
import SwmLib

/// Change global defaults in the running daemon.
struct ConfigCommand: ParsableCommand {
  struct AnimationDuration: ConfigIPCCommand {
    static let configuration = CommandConfiguration(
      abstract: "Show or set window animation duration."
    )
    static let command = "animation-duration"

    @Argument(help: "Seconds from 0 through 1. Default: 0, which disables animation.")
    var seconds: Double?

    var arguments: [String] { seconds.map { [String($0)] } ?? [] }
  }

  struct AnimationEasingCommand: ConfigIPCCommand {
    static let configuration = CommandConfiguration(
      commandName: "animation-easing",
      abstract: "Show or set window animation easing."
    )
    static let command = "animation-easing"

    @Argument(help: "Easing curve. Default: ease-out-quad.")
    var easing: AnimationEasing?

    var arguments: [String] { easing.map { [$0.rawValue] } ?? [] }
  }

  struct Layout: ConfigIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Show or set the default layout.")
    static let command = "layout"

    @Argument(help: "Layout used for all current and future Spaces.")
    var layout: LayoutName?

    var arguments: [String] { layout.map { [$0.rawValue] } ?? [] }
  }

  struct FocusFollowsMouse: ConfigIPCCommand {
    static let configuration = CommandConfiguration(
      abstract: "Show or set how pointer movement focuses windows."
    )
    static let command = "focus-follows-mouse"

    @Argument(help: "Focus mode used for managed windows.")
    var mode: FocusFollowsMouseName?

    var arguments: [String] { mode.map { [$0.rawValue] } ?? [] }
  }

  struct MasterRatio: ConfigIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Show or set the master-area ratio.")
    static let command = "master-ratio"

    @Argument(help: "Ratio from 0.1 through 0.9.")
    var ratio: Double?

    var arguments: [String] { ratio.map { [String($0)] } ?? [] }
  }

  struct MasterPlacement: ConfigIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Show or set the master-area edge.")
    static let command = "master-placement"

    @Argument(help: "Edge used by the master layout.")
    var placement: MasterPlacementName?

    var arguments: [String] { placement.map { [$0.rawValue] } ?? [] }
  }

  struct PreserveSplit: ConfigIPCCommand {
    static let configuration = CommandConfiguration(
      abstract: "Show or set whether dwindle split directions are retained."
    )
    static let command = "preserve-split"

    @Argument(help: "Enable or disable split preservation.")
    var state: ToggleState?

    var arguments: [String] { state.map { [$0.rawValue] } ?? [] }
  }

  struct Gap: ConfigIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Show or set the window gap.")
    static let command = "gap"

    @Argument(help: "Gap in points.")
    var points: Int?

    var arguments: [String] { points.map { [String($0)] } ?? [] }
  }

  struct Padding: ConfigIPCCommand {
    static let configuration = CommandConfiguration(
      abstract: "Show or set padding around every Space.",
      discussion: """
        Sides left out keep their padding. Without sides, prints the current padding.

        Example:
          swm config padding --top 6 --bottom 6 --left 6 --right 6
        """
    )
    static let command = "padding"

    @OptionGroup var sides: PaddingSideOptions

    var arguments: [String] { sides.arguments }

    func validate() throws {
      guard sides.changes.allSatisfy({ !$0.change.isRelative }) else {
        throw ValidationError("Global padding takes points, not signed changes.")
      }
    }
  }

  static let configuration = CommandConfiguration(
    commandName: "config",
    abstract: "Show or change global layout defaults.",
    discussion: "Run a setting without a value to print its current value.",
    subcommands: [
      Layout.self, FocusFollowsMouse.self, MasterRatio.self, MasterPlacement.self,
      PreserveSplit.self, AnimationDuration.self, AnimationEasingCommand.self,
      Gap.self, Padding.self,
    ]
  )
}

extension AnimationEasing: ExpressibleByArgument {}

enum MasterPlacementName: String, CaseIterable, ExpressibleByArgument {
  case left, right, top, bottom
}

enum FocusFollowsMouseName: String, CaseIterable, ExpressibleByArgument {
  case off, autofocus, autoraise
}
