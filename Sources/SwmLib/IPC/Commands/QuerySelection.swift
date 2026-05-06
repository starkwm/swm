import CoreGraphics

enum QuerySelection: Equatable {
  private static let commandFlags = Set(["--displays", "--spaces", "--windows"])
  private static let selectorFlags = Set(["--display", "--space", "--window"])

  case none
  case display(Int?)
  case space(Int?)
  case window(CGWindowID?)

  static func parse(arguments: [String]) throws -> QuerySelection {
    try parseComponents(arguments: arguments).selection
  }

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

  private static func selectorValues(after index: Int, in arguments: [String]) -> [String] {
    var values = [String]()
    var next = index + 1

    while next < arguments.count, !arguments[next].hasPrefix("--") {
      values.append(arguments[next])
      next += 1
    }

    return values
  }

  private static func parseIndex(_ value: String) throws -> Int {
    guard let index = Int(value), index >= 0 else {
      throw IPCCommandError.invalidRequest("query selector value must be a non-negative integer")
    }

    return index
  }

  private static func parseWindowID(_ value: String) throws -> CGWindowID {
    guard let id = UInt32(value) else {
      throw IPCCommandError.invalidRequest("query window selector value must be a window id")
    }

    return CGWindowID(id)
  }

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

  private func selectorArguments(flag: String, value: String?) -> [String] {
    if let value {
      [flag, value]
    } else {
      [flag]
    }
  }
}
