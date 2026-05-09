import CoreGraphics

/// Selector that narrows query results to a display, space, or window.
enum QuerySelection: Equatable {
  private static let commandFlags = Set(["--displays", "--spaces", "--windows"])
  private static let selectorFlags = Set(["--display", "--space", "--window"])

  /// No selector; query all items for the requested command.
  case none

  /// Select a display by index, or the focused display when the index is absent.
  case display(Int?)

  /// Select a space by index, or the focused space when the index is absent.
  case space(Int?)

  /// Select a window by ID, or the focused window when the ID is absent.
  case window(CGWindowID?)

  /// Parse selector arguments from an IPC request.
  static func parse(arguments: [String]) throws -> QuerySelection {
    try parseComponents(arguments: arguments).selection
  }

  /// Parse a query command and selector from command-line style arguments.
  static func parseRequest(arguments: [String]) throws -> (
    command: String, selection: QuerySelection
  ) {
    let (command, selection) = try parseComponents(arguments: arguments)

    if let command {
      return (command, selection)
    }

    if let command = selection.defaultCommand {
      return (command, selection)
    }

    throw IPCCommandError.invalidRequest("exactly one query flag is required")
  }

  /// Parse query command and selector flags while enforcing one of each.
  private static func parseComponents(
    arguments: [String]
  ) throws -> (command: String?, selection: QuerySelection) {
    var command: String?
    var selection: QuerySelection = .none
    var index = 0

    while index < arguments.count {
      let argument = arguments[index]

      if commandFlags.contains(argument) {
        guard command == nil else {
          throw IPCCommandError.invalidRequest("exactly one query flag is required")
        }

        command = argument
        index += 1

        continue
      }

      guard selectorFlags.contains(argument) else {
        throw IPCCommandError.invalidRequest("unsupported query argument: \(argument)")
      }

      guard selection == .none else {
        throw IPCCommandError.invalidRequest("only one query selector is allowed")
      }

      let values = selectorValues(after: index, in: arguments)
      guard values.count <= 1 else {
        throw IPCCommandError.invalidRequest("query selector accepts at most one value")
      }

      let value = values.first

      switch argument {
      case "--display":
        selection = try .display(value.map(parseIndex))
      case "--space":
        selection = try .space(value.map(parseIndex))
      case "--window":
        selection = try .window(value.map(parseWindowID))
      default:
        break
      }

      index += values.count + 1
    }

    return (command, selection)
  }

  /// Return non-flag values following a selector flag.
  private static func selectorValues(after index: Int, in arguments: [String]) -> [String] {
    var values = [String]()
    var next = index + 1

    while next < arguments.count, !arguments[next].hasPrefix("--") {
      values.append(arguments[next])
      next += 1
    }

    return values
  }

  /// Parse a non-negative display or space index.
  private static func parseIndex(_ value: String) throws -> Int {
    guard let index = Int(value), index >= 0 else {
      throw IPCCommandError.invalidRequest("query selector value must be a non-negative integer")
    }

    return index
  }

  /// Parse a Core Graphics window ID.
  private static func parseWindowID(_ value: String) throws -> CGWindowID {
    guard let id = UInt32(value) else {
      throw IPCCommandError.invalidRequest("query window selector value must be a window id")
    }

    return CGWindowID(id)
  }

  /// Command-line arguments that reproduce this selector.
  var requestArguments: [String] {
    switch self {
    case .none:
      []
    case .display(let value):
      selectorArguments(flag: "--display", value: value.map(String.init))
    case .space(let value):
      selectorArguments(flag: "--space", value: value.map(String.init))
    case .window(let value):
      selectorArguments(flag: "--window", value: value.map(String.init))
    }
  }

  /// The query command implied by this selector when no explicit command is supplied.
  var defaultCommand: String? {
    switch self {
    case .none:
      nil
    case .display:
      "--displays"
    case .space:
      "--spaces"
    case .window:
      "--windows"
    }
  }

  /// Build command-line style arguments for a selector flag and optional value.
  private func selectorArguments(flag: String, value: String?) -> [String] {
    if let value {
      [flag, value]
    } else {
      [flag]
    }
  }
}
