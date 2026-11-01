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

  struct MasterRatio: ConfigIPCCommand, SettingChangeCommand {
    static let configuration = CommandConfiguration(
      abstract: "Show, set, or adjust the master-area ratio.",
      discussion: """
        A signed change adjusts the global ratio and applies the result to every Space.

        Examples:
          swm config master-ratio 0.6
          swm config master-ratio -0.05
        """
    )
    static let command = "master-ratio"

    @Argument(help: "Ratio from 0.1 through 0.9, or a signed change such as +0.05.")
    var ratio: SettingChange<Double>?

    var arguments: [String] { ratio.map { [$0.ipcValue] } ?? [] }

    func validate() throws {
      try ratio?.validate(0.1...0.9, name: "Master ratio")
    }
  }

  struct MasterPlacement: ConfigIPCCommand {
    static let configuration = CommandConfiguration(
      abstract: "Show, set, or cycle the master-area edge.",
      discussion: "next and prev cycle from the global edge and apply the result to every Space."
    )
    static let command = "master-placement"

    @Argument(help: "Master edge or next/prev.")
    var placement: MasterPlacementName?

    var arguments: [String] { placement.map { [$0.rawValue] } ?? [] }
  }

  struct SplitRatio: ConfigIPCCommand, SettingChangeCommand {
    static let configuration = CommandConfiguration(
      abstract: "Show, set, or adjust the dwindle split ratio.",
      discussion: """
        Sets the ratio used by new dwindle splits and rebalances every existing split to it. \
        A signed change adjusts the global ratio and applies the result to every Space.

        Examples:
          swm config split-ratio 0.6
          swm config split-ratio -0.05
        """
    )
    static let command = "split-ratio"

    @Argument(help: "Ratio from 0.1 through 0.9, or a signed change such as +0.05.")
    var ratio: SettingChange<Double>?

    var arguments: [String] { ratio.map { [$0.ipcValue] } ?? [] }

    func validate() throws {
      try ratio?.validate(0.1...0.9, name: "Split ratio")
    }
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

  struct Gap: ConfigIPCCommand, SettingChangeCommand {
    static let configuration = CommandConfiguration(
      abstract: "Show, set, or adjust the window gap.",
      discussion: """
        A signed change adjusts the global gap and applies the result to every Space.

        Examples:
          swm config gap 6
          swm config gap +2
        """
    )
    static let command = "gap"

    @Argument(help: "Points to set, or a signed change such as +2 or -2.")
    var points: SettingChange<Int>?

    var arguments: [String] { points.map { [$0.ipcValue] } ?? [] }
  }

  struct Padding: ConfigIPCCommand, SettingChangeCommand {
    static let configuration = CommandConfiguration(
      abstract: "Show, set, or adjust padding around every Space.",
      discussion: """
        Each side takes points to set, or a signed change to the global padding. Changed \
        sides apply to every Space; sides left out keep their padding. Without sides, \
        prints the current padding.

        Examples:
          swm config padding --top 6 --bottom 6 --left 6 --right 6
          swm config padding --top +4
        """
    )
    static let command = "padding"

    @OptionGroup var sides: PaddingSideOptions

    var arguments: [String] { sides.arguments }
  }

  static let configuration = CommandConfiguration(
    commandName: "config",
    abstract: "Show or change global layout defaults.",
    discussion: "Run a setting without a value to print its current value.",
    subcommands: [
      Layout.self, FocusFollowsMouse.self, MasterRatio.self, MasterPlacement.self,
      SplitRatio.self, PreserveSplit.self, AnimationDuration.self, AnimationEasingCommand.self,
      Gap.self, Padding.self,
    ]
  )
}

extension AnimationEasing: ExpressibleByArgument {}

enum FocusFollowsMouseName: String, CaseIterable, ExpressibleByArgument {
  case off, autofocus, autoraise
}
