import ArgumentParser
import SwmLib

struct ConfigCommand: ParsableCommand {
  struct AnimationDuration: DaemonCommand {
    static let configuration = CommandConfiguration(
      abstract: "Show or set window animation duration."
    )

    @Argument(help: "Seconds from 0 through 1. Default: 0, which disables animation.")
    var seconds: Double?

    var ipcCommand: IPCCommand { .config(.animationDuration(seconds)) }
  }

  struct AnimationEasingCommand: DaemonCommand {
    static let configuration = CommandConfiguration(
      commandName: "animation-easing",
      abstract: "Show or set window animation easing."
    )

    @Argument(help: "Easing curve. Default: ease-out-quad.")
    var easing: AnimationEasing?

    var ipcCommand: IPCCommand { .config(.animationEasing(easing)) }
  }

  struct Layout: DaemonCommand {
    static let configuration = CommandConfiguration(abstract: "Show or set the layout.")

    @OptionGroup var scope: ConfigScopeOptions

    @Argument(help: "Layout used in the selected scope.")
    var layout: LayoutSelection?

    var ipcCommand: IPCCommand { .config(.layout(scope: scope.configScope, layout)) }
  }

  struct FocusFollowsMouse: DaemonCommand {
    static let configuration = CommandConfiguration(
      abstract: "Show or set how pointer movement focuses windows."
    )

    @Argument(help: "Focus mode used for managed windows.")
    var mode: FocusFollowsMouseMode?

    var ipcCommand: IPCCommand { .config(.focusFollowsMouse(mode)) }
  }

  struct MasterRatio: DaemonCommand, SignedPositionalCommand {
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
    static let valueOptions: Set<String> = ["--space"]

    @OptionGroup var scope: ConfigScopeOptions

    @Argument(help: "Ratio from 0.1 through 0.9, or a signed change such as +0.05.")
    var ratio: SettingChange<Double>?

    var ipcCommand: IPCCommand {
      .config(.masterRatio(scope: scope.configScope, ratio?.ratioChange))
    }

    func validate() throws {
      try ratio?.validate(0.1...0.9, name: "Master ratio")
    }
  }

  struct MasterPlacement: DaemonCommand {
    static let configuration = CommandConfiguration(
      abstract: "Show, set, or cycle the master-area edge.",
      discussion:
        "next and prev cycle within the selected scope. Without --space, the result applies to every Space."
    )

    @OptionGroup var scope: ConfigScopeOptions

    @Argument(help: "Master edge or next/prev.")
    var placement: MasterPlacementName?

    var ipcCommand: IPCCommand {
      .config(.masterPlacement(scope: scope.configScope, placement?.change))
    }
  }

  struct SplitRatio: DaemonCommand, SignedPositionalCommand {
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
    static let valueOptions: Set<String> = ["--space"]

    @OptionGroup var scope: ConfigScopeOptions

    @Argument(help: "Ratio from 0.1 through 0.9, or a signed change such as +0.05.")
    var ratio: SettingChange<Double>?

    var ipcCommand: IPCCommand {
      .config(.splitRatio(scope: scope.configScope, ratio?.ratioChange))
    }

    func validate() throws {
      try ratio?.validate(0.1...0.9, name: "Split ratio")
    }
  }

  struct PreserveSplit: DaemonCommand {
    static let configuration = CommandConfiguration(
      abstract: "Show or set whether dwindle split directions are retained."
    )

    @OptionGroup var scope: ConfigScopeOptions

    @Argument(help: "Enable or disable split preservation.")
    var state: ToggleState?

    var ipcCommand: IPCCommand {
      .config(.preserveSplit(scope: scope.configScope, state?.isEnabled))
    }
  }

  struct Gap: DaemonCommand, SignedPositionalCommand {
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
    static let valueOptions: Set<String> = ["--space"]

    @OptionGroup var scope: ConfigScopeOptions

    @Argument(help: "Points to set, or a signed change such as +2 or -2.")
    var points: SettingChange<Int>?

    var ipcCommand: IPCCommand {
      .config(.gap(scope: scope.configScope, points?.numericChange))
    }
  }

  struct Padding: DaemonCommand, SignedPositionalCommand {
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
    static let valueOptions: Set<String> = ["--space", "--top", "--bottom", "--left", "--right"]

    @OptionGroup var scope: ConfigScopeOptions

    @OptionGroup var sides: PaddingSideOptions

    var ipcCommand: IPCCommand { .config(.padding(scope: scope.configScope, sides.changes)) }
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

extension FocusFollowsMouseMode: ExpressibleByArgument {}

extension LayoutSelection: ExpressibleByArgument {}

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

  var changes: [PaddingSideChange] {
    [
      (PaddingSide.top, top ?? points),
      (PaddingSide.bottom, bottom ?? points),
      (PaddingSide.left, left ?? points),
      (PaddingSide.right, right ?? points),
    ]
    .compactMap { side, change in
      change.map { PaddingSideChange(side: side, change: $0.numericChange) }
    }
  }
}

struct ConfigScopeOptions: ParsableArguments {
  @Option(
    name: .long,
    help:
      "Select current or a positive one-based Space index. Omit for global defaults and all Spaces."
  )
  var space: ConfigSpaceTarget?

  var configScope: ConfigScope {
    switch space {
    case nil: .global
    case .current: .currentSpace
    case .index(let index): .space(index)
    }
  }
}

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
