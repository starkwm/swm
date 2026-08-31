import ArgumentParser
import SwmLib

/// Configure a space.
struct SpaceCommand: ParsableCommand {
  struct TargetOptions: ParsableArguments {
    @Option(
      name: .long,
      help: ArgumentHelp(
        "Zero-based space index; defaults to active.",
        valueName: "space-index"
      )
    )
    var space: Int?

    var arguments: [String] {
      space.map { ["--space", String($0)] } ?? []
    }

    func validate() throws {
      if let space, space < 0 {
        throw ValidationError("Space index must not be negative.")
      }
    }
  }

  static let configuration = CommandConfiguration(
    commandName: "space",
    abstract: "Configure a space.",
    subcommands: [
      Layout.self, MasterRatio.self, MasterPlacement.self, PreserveSplit.self, Padding.self,
      Gap.self,
    ]
  )

  struct Layout: SpaceIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Set a space layout.")
    static let command = "--layout"

    @OptionGroup var target: TargetOptions

    @Argument(help: "Layout used by the selected space.")
    var layout: LayoutName

    var arguments: [String] { target.arguments + [layout.rawValue] }
  }

  struct MasterRatio: SpaceIPCCommand {
    static let configuration = CommandConfiguration(
      abstract: "Set or adjust a space master ratio."
    )
    static let command = "--master-ratio"

    @OptionGroup var target: TargetOptions

    @Argument(help: "Change in the form abs:<ratio> or rel:<ratio>.")
    var change: String

    var arguments: [String] { target.arguments + [change] }
  }

  struct MasterPlacement: SpaceIPCCommand {
    static let configuration = CommandConfiguration(
      abstract: "Set or cycle a space master edge."
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

  struct Padding: SpaceIPCCommand {
    static let configuration = CommandConfiguration(
      abstract: "Set or adjust padding around a space."
    )
    static let command = "--padding"

    @OptionGroup var target: TargetOptions

    @Argument(help: "Change in the form abs|rel:<top>:<bottom>:<left>:<right>.")
    var change: String

    var arguments: [String] { target.arguments + [change] }
  }

  struct Gap: SpaceIPCCommand {
    static let configuration = CommandConfiguration(
      abstract: "Set or adjust a space window gap."
    )
    static let command = "--gap"

    @OptionGroup var target: TargetOptions

    @Argument(help: "Change in the form abs:<points> or rel:<points>.")
    var change: String

    var arguments: [String] { target.arguments + [change] }
  }
}

enum SpaceMasterPlacementName: String, CaseIterable, ExpressibleByArgument {
  case left, right, top, bottom, next, prev
}
