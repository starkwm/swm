import ArgumentParser
import SwmLib

/// Activate a desktop Space.
struct SpaceCommand: ParsableCommand {
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

  static let configuration = CommandConfiguration(
    commandName: "space",
    abstract: "Activate a desktop Space.",
    subcommands: [Activate.self]
  )
}
