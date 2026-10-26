import ArgumentParser
import SwmLib

/// Activate or configure a space.
struct SpaceCommand: ParsableCommand {
  struct TargetOptions: ParsableArguments {
    @Option(
      name: .long,
      help: ArgumentHelp(
        "One-based Space index; defaults to active.",
        valueName: "space-index"
      )
    )
    var space: Int?

    var arguments: [String] {
      space.map { ["--space", String($0)] } ?? []
    }

    func validate() throws {
      if let space, space < 1 {
        throw ValidationError("Space index must be positive.")
      }
    }
  }

  static let configuration = CommandConfiguration(
    commandName: "space",
    abstract: "Activate or configure a Space.",
    subcommands: [
      Activate.self, Layout.self, MasterRatio.self, MasterPlacement.self, PreserveSplit.self,
      Padding.self,
      Gap.self,
    ]
  )

  struct Activate: SpaceIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Activate a desktop Space.")
    static let command = "--activate"

    @Argument(help: "One-based Space index from swm query spaces.")
    var index: Int

    var arguments: [String] { [String(index)] }

    func validate() throws {
      guard index >= 1 else {
        throw ValidationError("Space index must be positive.")
      }
    }
  }

  struct Layout: SpaceIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Set a Space layout.")
    static let command = "--layout"

    @OptionGroup var target: TargetOptions

    @Argument(help: "Layout used by the selected Space.")
    var layout: LayoutName

    var arguments: [String] { target.arguments + [layout.rawValue] }
  }

  struct MasterRatio: SpaceIPCCommand, SettingChangeCommand {
    static let configuration = CommandConfiguration(
      abstract: "Set or adjust a Space master ratio.",
      discussion: """
        Examples:
          swm space master-ratio 0.6
          swm space master-ratio -0.05
        """
    )
    static let command = "--master-ratio"

    @OptionGroup var target: TargetOptions

    @Argument(help: "Ratio from 0.1 through 0.9, or a signed change such as +0.05.")
    var ratio: SettingChange<Double>

    var arguments: [String] { target.arguments + [ratio.ipcValue] }

    func validate() throws {
      try ratio.validate(0.1...0.9, name: "Master ratio")
    }
  }

  struct MasterPlacement: SpaceIPCCommand {
    static let configuration = CommandConfiguration(
      abstract: "Set or cycle a Space master edge."
    )
    static let command = "--master-placement"

    @OptionGroup var target: TargetOptions

    @Argument(help: "Master edge or next/prev.")
    var placement: SpaceMasterPlacementName

    var arguments: [String] { target.arguments + [placement.rawValue] }
  }

  struct PreserveSplit: SpaceIPCCommand {
    static let configuration = CommandConfiguration(
      abstract: "Set whether dwindle split directions are retained."
    )
    static let command = "--preserve-split"

    @OptionGroup var target: TargetOptions

    @Argument(help: "Enable or disable split preservation.")
    var state: ToggleState

    var arguments: [String] { target.arguments + [state.rawValue] }
  }

  struct Padding: SpaceIPCCommand, SettingChangeCommand {
    static let configuration = CommandConfiguration(
      abstract: "Set or adjust padding around a Space.",
      discussion: """
        Each side takes points to set, or a signed change. Sides left out keep their \
        padding.

        Examples:
          swm space padding --top 8 --bottom 8 --left 8 --right 8
          swm space padding --top +4
        """
    )
    static let command = "--padding"

    @OptionGroup var target: TargetOptions
    @OptionGroup var sides: PaddingSideOptions

    var arguments: [String] { target.arguments + sides.arguments }

    func validate() throws {
      guard !sides.changes.isEmpty else {
        throw ValidationError("Provide at least one of --top, --bottom, --left, or --right.")
      }
    }
  }

  struct Gap: SpaceIPCCommand, SettingChangeCommand {
    static let configuration = CommandConfiguration(
      abstract: "Set or adjust a Space window gap.",
      discussion: """
        Examples:
          swm space gap 6
          swm space gap +2
        """
    )
    static let command = "--gap"

    @OptionGroup var target: TargetOptions

    @Argument(help: "Points to set, or a signed change such as +2 or -2.")
    var points: SettingChange<Int>

    var arguments: [String] { target.arguments + [points.ipcValue] }
  }
}

/// Padding sides shared by the Space and global padding commands.
struct PaddingSideOptions: ParsableArguments {
  @Option(help: ArgumentHelp("Top padding.", valueName: "points"))
  var top: SettingChange<Int>?

  @Option(help: ArgumentHelp("Bottom padding.", valueName: "points"))
  var bottom: SettingChange<Int>?

  @Option(help: ArgumentHelp("Left padding.", valueName: "points"))
  var left: SettingChange<Int>?

  @Option(help: ArgumentHelp("Right padding.", valueName: "points"))
  var right: SettingChange<Int>?

  /// Sides given on the command line, in IPC order.
  var changes: [(side: String, change: SettingChange<Int>)] {
    [("top", top), ("bottom", bottom), ("left", left), ("right", right)]
      .compactMap { side, change in change.map { (side, $0) } }
  }

  /// IPC arguments in `side=abs:<points>` or `side=rel:<points>` form.
  var arguments: [String] { changes.map { "\($0.side)=\($0.change.ipcValue)" } }
}

enum SpaceMasterPlacementName: String, CaseIterable, ExpressibleByArgument {
  case left, right, top, bottom, next, prev
}
