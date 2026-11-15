import CoreGraphics

enum QuerySelection: Equatable {
  case none

  case display(Int?)

  case space(Int?)

  case window(CGWindowID?)

  private static let selectorFlags = Set(["--display", "--space", "--window"])

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

  private static func selectorValues(after index: Int, in arguments: [String]) -> [String] {
    var values = [String]()
    var next = index + 1

    while next < arguments.count, !arguments[next].hasPrefix("--") {
      values.append(arguments[next])
      next += 1
    }

    return values
  }

  private static func parseIndex(_ value: String, selector: String) throws -> Int {
    guard let index = Int(value), index > 0 else {
      throw IPCCommandError.invalidRequest(
        "query \(selector) selector value must be a positive integer"
      )
    }

    return index
  }

  private static func parseWindowID(_ value: String) throws -> CGWindowID {
    guard let id = UInt32(value) else {
      throw IPCCommandError.invalidRequest("query window selector value must be a window id")
    }

    return CGWindowID(id)
  }
}
