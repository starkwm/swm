import ArgumentParser
import SwmLib

/// Reject a provided index that is not one-based.
private func validatePositiveIndex(_ index: Int?, name: String) throws {
  if let index, index < 1 {
    throw ValidationError("\(name) index must be positive.")
  }
}

/// Query displays, spaces, and windows tracked by the daemon.
struct QueryCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "query",
    abstract: "Query displays, Spaces, and windows.",
    discussion: "Results are JSON, indented for a terminal and on one line for pipes.",
    subcommands: [Displays.self, Spaces.self, Windows.self, Display.self, Space.self, Window.self]
  )

  struct Displays: QueryIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Query all displays.")
    static let command = "--displays"

    @OptionGroup var selector: QuerySelectorOptions

    var arguments: [String] { selector.arguments }
  }

  struct Spaces: QueryIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Query all Spaces.")
    static let command = "--spaces"

    @OptionGroup var selector: QuerySelectorOptions

    var arguments: [String] { selector.arguments }
  }

  struct Windows: QueryIPCCommand {
    static let configuration = CommandConfiguration(abstract: "Query all windows.")
    static let command = "--windows"

    @OptionGroup var selector: QuerySelectorOptions

    var arguments: [String] { selector.arguments }
  }

  struct Display: QueryIPCCommand {
    static let configuration = CommandConfiguration(
      abstract: "Query a display by index, or the focused display."
    )
    static let command = "--display"

    @Argument(help: "One-based display index.")
    var index: Int?

    var arguments: [String] { index.map { [String($0)] } ?? [] }

    func validate() throws {
      try validatePositiveIndex(index, name: "Display")
    }
  }

  struct Space: QueryIPCCommand {
    static let configuration = CommandConfiguration(
      abstract: "Query a Space by index, or the focused Space."
    )
    static let command = "--space"

    @Argument(help: "One-based Space index.")
    var index: Int?

    var arguments: [String] { index.map { [String($0)] } ?? [] }

    func validate() throws {
      try validatePositiveIndex(index, name: "Space")
    }
  }

  struct Window: QueryIPCCommand {
    static let configuration = CommandConfiguration(
      abstract: "Query a window by ID, or the focused window."
    )
    static let command = "--window"

    @Argument(help: "Window ID.")
    var id: UInt32?

    var arguments: [String] { id.map { [String($0)] } ?? [] }
  }
}

/// An optional selector shared by plural query commands.
struct QuerySelectorOptions: ParsableArguments {
  @Option(help: "Filter by one-based display index.") var display: Int?
  @Option(help: "Filter by one-based Space index.") var space: Int?
  @Option(help: "Filter by window ID.") var window: UInt32?

  var arguments: [String] {
    if let display { return ["--display", String(display)] }
    if let space { return ["--space", String(space)] }
    if let window { return ["--window", String(window)] }
    return []
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
