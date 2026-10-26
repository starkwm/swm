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

  struct MasterRatio: SpaceIPCCommand {
    static let configuration = CommandConfiguration(
      abstract: "Set or adjust a Space master ratio.",
      discussion: """
        Examples:
          swm space master-ratio abs:0.6
          swm space master-ratio rel:-0.05
        """
    )
    static let command = "--master-ratio"

    @OptionGroup var target: TargetOptions

    @Argument(help: "Change in the form abs:<ratio> or rel:<ratio>.")
    var change: String

    var arguments: [String] { target.arguments + [change] }
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

  struct Padding: SpaceIPCCommand {
    static let configuration = CommandConfiguration(
      abstract: "Set or adjust padding around a Space.",
      discussion: """
        Values are top, bottom, left, and right, in points.

        Examples:
          swm space padding abs:8:8:8:8
          swm space padding rel:4:0:0:0
        """
    )
    static let command = "--padding"

    @OptionGroup var target: TargetOptions

    @Argument(help: "Change in the form abs|rel:<top>:<bottom>:<left>:<right>.")
    var change: String

    var arguments: [String] { target.arguments + [change] }
  }

  struct Gap: SpaceIPCCommand {
    static let configuration = CommandConfiguration(
      abstract: "Set or adjust a Space window gap.",
      discussion: """
        Examples:
          swm space gap abs:6
          swm space gap rel:2
        """
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
