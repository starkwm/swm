import CoreGraphics

/// Selector that narrows query results to a display, space, or window.
enum QuerySelection: Equatable {
  /// No selector; query all items for the requested command.
  case none

  /// Select a display by one-based arrangement index, or the focused display when absent.
  case display(Int?)

  /// Select a space by index, or the focused space when the index is absent.
  case space(Int?)

  /// Select a window by ID, or the focused window when the ID is absent.
  case window(CGWindowID?)

  private static let selectorFlags = Set(["--display", "--space", "--window"])

  /// Parse at most one selector flag from an IPC request's arguments.
  static func parse(arguments: [String]) throws -> QuerySelection {
    var selection: QuerySelection = .none
    var index = 0

    while index < arguments.count {
      let argument = arguments[index]

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
        selection = try .display(value.map { try parseIndex($0, selector: "display") })
      case "--space":
        selection = try .space(value.map { try parseIndex($0, selector: "space") })
      case "--window":
        selection = try .window(value.map(parseWindowID))
      default:
        break
      }

      index += values.count + 1
    }

    return selection
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

  /// Parse a positive one-based display or Space index for the named selector.
  private static func parseIndex(_ value: String, selector: String) throws -> Int {
    guard let index = Int(value), index > 0 else {
      throw IPCCommandError.invalidRequest(
        "query \(selector) selector value must be a positive integer"
      )
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
}
