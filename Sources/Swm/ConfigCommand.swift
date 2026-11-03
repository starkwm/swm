import ArgumentParser
import SwmLib

/// Change global defaults or selected Space settings in the running daemon.
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

  struct Layout: ScopedConfigIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Show or set the layout.")
    static let command = "layout"

    @OptionGroup var scope: ConfigScopeOptions

    @Argument(help: "Layout used in the selected scope.")
    var layout: LayoutName?

    var settingArguments: [String] { layout.map { [$0.rawValue] } ?? [] }
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

  struct MasterRatio: ScopedConfigIPCCommand, SettingChangeCommand {
    static let configuration = CommandConfiguration(
      abstract: "Show, set, or adjust the master-area ratio.",
      discussion: """
        Without --space, a signed change adjusts the global ratio and applies it to every Space.
        With --space, it adjusts only the selected Space.

        Examples:
          swm config master-ratio 0.6
          swm config master-ratio -0.05
        """
    )
    static let command = "master-ratio"

    @OptionGroup var scope: ConfigScopeOptions

    @Argument(help: "Ratio from 0.1 through 0.9, or a signed change such as +0.05.")
    var ratio: SettingChange<Double>?

    var settingArguments: [String] { ratio.map { [$0.ipcValue] } ?? [] }

    func validate() throws {
      try ratio?.validate(0.1...0.9, name: "Master ratio")
    }
  }

  struct MasterPlacement: ScopedConfigIPCCommand {
    static let configuration = CommandConfiguration(
      abstract: "Show, set, or cycle the master-area edge.",
      discussion:
        "next and prev cycle within the selected scope. Without --space, the result applies to every Space."
    )
    static let command = "master-placement"

    @OptionGroup var scope: ConfigScopeOptions

    @Argument(help: "Master edge or next/prev.")
    var placement: MasterPlacementName?

    var settingArguments: [String] { placement.map { [$0.rawValue] } ?? [] }
  }

  struct SplitRatio: ScopedConfigIPCCommand, SettingChangeCommand {
    static let configuration = CommandConfiguration(
      abstract: "Show, set, or adjust the dwindle split ratio.",
      discussion: """
        Sets the ratio used by new dwindle splits and rebalances existing splits in the selected scope. \
        Without --space, a signed change adjusts the global ratio and applies it to every Space.
        With --space, it adjusts only the selected Space.

        Examples:
          swm config split-ratio 0.6
          swm config split-ratio -0.05
        """
    )
    static let command = "split-ratio"

    @OptionGroup var scope: ConfigScopeOptions

    @Argument(help: "Ratio from 0.1 through 0.9, or a signed change such as +0.05.")
    var ratio: SettingChange<Double>?

    var settingArguments: [String] { ratio.map { [$0.ipcValue] } ?? [] }

    func validate() throws {
      try ratio?.validate(0.1...0.9, name: "Split ratio")
    }
  }

  struct PreserveSplit: ScopedConfigIPCCommand {
    static let configuration = CommandConfiguration(
      abstract: "Show or set whether dwindle split directions are retained."
    )
    static let command = "preserve-split"

    @OptionGroup var scope: ConfigScopeOptions

    @Argument(help: "Enable or disable split preservation.")
    var state: ToggleState?

    var settingArguments: [String] { state.map { [$0.rawValue] } ?? [] }
  }

  struct Gap: ScopedConfigIPCCommand, SettingChangeCommand {
    static let configuration = CommandConfiguration(
      abstract: "Show, set, or adjust the window gap.",
      discussion: """
        Without --space, a signed change adjusts the global gap and applies it to every Space.
        With --space, it adjusts only the selected Space.

        Examples:
          swm config gap 6
          swm config gap +2
          swm config gap --space current 8
          swm config gap --space 2 +2
        """
    )
    static let command = "gap"

    @OptionGroup var scope: ConfigScopeOptions

    @Argument(help: "Points to set, or a signed change such as +2 or -2.")
    var points: SettingChange<Int>?

    var settingArguments: [String] { points.map { [$0.ipcValue] } ?? [] }
  }

  struct Padding: ScopedConfigIPCCommand, SettingChangeCommand {
    static let configuration = CommandConfiguration(
      abstract: "Show, set, or adjust Space padding.",
      discussion: """
        A positional value sets or adjusts every side in the selected scope. Side flags \
        override that value for their side, regardless of argument order. Each adjustment \
        uses the current padding in that scope. Without --space, changed sides apply to every Space. Without a \
        positional value, sides left out keep their padding. Without values, prints the \
        current padding.

        Examples:
          swm config padding 8
          swm config padding 8 --top +4
          swm config padding --top +4
        """
    )
    static let command = "padding"

    @OptionGroup var scope: ConfigScopeOptions

    @OptionGroup var sides: PaddingSideOptions

    var settingArguments: [String] { sides.arguments }
  }

  static let configuration = CommandConfiguration(
    commandName: "config",
    abstract: "Show or change global defaults or selected Space settings.",
    discussion: """
      Run a setting without a value to print its current value. Shared layout, ratio, \
      placement, padding, and gap settings default to all current Spaces and future defaults. \
      Use --space current or --space <positive-index> to select only one Space. Animation \
      and focus-follows-mouse settings are global only.
      """,
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

/// Padding sides for global or selected Space settings.
struct PaddingSideOptions: ParsableArguments {
  @Argument(help: "Points for every side, or a signed change such as +2 or -2.")
  var points: SettingChange<Int>?

  @Option(parsing: .unconditional, help: ArgumentHelp("Top padding.", valueName: "points"))
  var top: SettingChange<Int>?

  @Option(parsing: .unconditional, help: ArgumentHelp("Bottom padding.", valueName: "points"))
  var bottom: SettingChange<Int>?

  @Option(parsing: .unconditional, help: ArgumentHelp("Left padding.", valueName: "points"))
  var left: SettingChange<Int>?

  @Option(parsing: .unconditional, help: ArgumentHelp("Right padding.", valueName: "points"))
  var right: SettingChange<Int>?

  /// Effective side changes, with side flags taking precedence, in IPC order.
  var changes: [(side: String, change: SettingChange<Int>)] {
    [
      ("top", top ?? points), ("bottom", bottom ?? points),
      ("left", left ?? points), ("right", right ?? points),
    ]
    .compactMap { side, change in change.map { (side, $0) } }
  }

  /// IPC arguments in `side=abs:<points>` or `side=rel:<points>` form.
  var arguments: [String] { changes.map { "\($0.side)=\($0.change.ipcValue)" } }
}

/// Explicit Space selection; omission keeps global semantics.
struct ConfigScopeOptions: ParsableArguments {
  @Option(
    name: .long,
    help:
      "Select current or a positive one-based Space index. Omit for global defaults and all Spaces."
  )
  var space: ConfigSpaceTarget?

  var arguments: [String] {
    guard case .index(let index) = space else { return [] }
    return ["--space", String(index)]
  }
}

/// A validated CLI selector translated to the existing Space IPC handler.
enum ConfigSpaceTarget: ExpressibleByArgument {
  case current
  case index(Int)

  init?(argument: String) {
    if argument == "current" {
      self = .current
    } else if let index = Int(argument), index > 0 {
      self = .index(index)
    } else {
      return nil
    }
  }
}
