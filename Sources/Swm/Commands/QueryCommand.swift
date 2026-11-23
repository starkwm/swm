import ArgumentParser
import CoreGraphics
import SwmLib

private func validatePositiveIndex(_ index: Int?, name: String) throws {
  if let index, index < 1 {
    throw ValidationError("\(name) index must be positive.")
  }
}

struct QueryCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "query",
    abstract: "Query displays, Spaces, and windows.",
    discussion: "Results are JSON, indented for a terminal and on one line for pipes.",
    subcommands: [Displays.self, Spaces.self, Windows.self, Display.self, Space.self, Window.self]
  )

  struct Displays: QueryDaemonCommand {
    static let configuration = CommandConfiguration(abstract: "Query all displays.")

    @OptionGroup var selector: QuerySelectorOptions

    var ipcCommand: IPCCommand { .query(.displays, selector.selection) }
  }

  struct Spaces: QueryDaemonCommand {
    static let configuration = CommandConfiguration(abstract: "Query all Spaces.")

    @OptionGroup var selector: QuerySelectorOptions

    var ipcCommand: IPCCommand { .query(.spaces, selector.selection) }
  }

  struct Windows: QueryDaemonCommand {
    static let configuration = CommandConfiguration(abstract: "Query all windows.")

    @OptionGroup var selector: QuerySelectorOptions

    var ipcCommand: IPCCommand { .query(.windows, selector.selection) }
  }

  struct Display: QueryDaemonCommand {
    static let configuration = CommandConfiguration(
      abstract: "Query a display by index, or the focused display."
    )

    @Argument(help: "One-based display index.")
    var index: Int?

    var ipcCommand: IPCCommand { .query(.displays, .display(index)) }

    func validate() throws {
      try validatePositiveIndex(index, name: "Display")
    }
  }

  struct Space: QueryDaemonCommand {
    static let configuration = CommandConfiguration(
      abstract: "Query a Space by index, or the focused Space."
    )

    @Argument(help: "One-based Space index.")
    var index: Int?

    var ipcCommand: IPCCommand { .query(.spaces, .space(index)) }

    func validate() throws {
      try validatePositiveIndex(index, name: "Space")
    }
  }

  struct Window: QueryDaemonCommand {
    static let configuration = CommandConfiguration(
      abstract: "Query a window by ID, or the focused window."
    )

    @Argument(help: "Window ID.")
    var id: UInt32?

    var ipcCommand: IPCCommand { .query(.windows, .window(id)) }
  }
}

struct QuerySelectorOptions: ParsableArguments {
  @Option(help: "Filter by one-based display index.") var display: Int?
  @Option(help: "Filter by one-based Space index.") var space: Int?
  @Option(help: "Filter by window ID.") var window: UInt32?

  var selection: QuerySelection {
    if let display { return .display(display) }
    if let space { return .space(space) }
    if let window { return .window(CGWindowID(window)) }
    return .none
  }

  func validate() throws {
    let selectionCount = [display != nil, space != nil, window != nil].count(where: { $0 })
    if selectionCount > 1 {
      throw ValidationError("Only one query selector can be provided.")
    }
    try validatePositiveIndex(display, name: "Display")
    try validatePositiveIndex(space, name: "Space")
  }
}
