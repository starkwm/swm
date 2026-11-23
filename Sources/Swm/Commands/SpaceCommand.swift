import ArgumentParser
import SwmLib

struct SpaceCommand: ParsableCommand {
  struct Activate: DaemonCommand {
    static let configuration = CommandConfiguration(abstract: "Activate a desktop Space.")

    @Argument(help: "One-based Space index from swm query spaces.")
    var index: Int

    var ipcCommand: IPCCommand { .spaceActivate(index: index) }

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
