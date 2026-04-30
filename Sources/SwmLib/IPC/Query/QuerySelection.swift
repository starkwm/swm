import ArgumentParser
import CoreGraphics

enum QuerySelection: Equatable {
  case none
  case display(Int?)
  case space(Int?)
  case window(CGWindowID?)

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

  static func parse(arguments: [String]) throws -> QuerySelection {
    var selection: QuerySelection = .none
    var index = 0
    let targetFlags = Set(["--displays", "--spaces", "--windows"])

    while index < arguments.count {
      let argument = arguments[index]

      if targetFlags.contains(argument) {
        index += 1
        continue
      }

      guard ["--display", "--space", "--window"].contains(argument) else {
        throw ValidationError("unsupported query argument: \(argument)")
      }

      guard selection == .none else {
        throw ValidationError("only one query selector is allowed")
      }

      let values = selectorValues(after: index, in: arguments)
      guard values.count <= 1 else {
        throw ValidationError("query selector accepts at most one value")
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

  private static func parseIndex(_ value: String) throws -> Int {
    guard let index = Int(value), index >= 0 else {
      throw ValidationError("query selector value must be a non-negative integer")
    }

    return index
  }

  private static func parseWindowID(_ value: String) throws -> CGWindowID {
    guard let id = UInt32(value) else {
      throw ValidationError("query window selector value must be a window id")
    }

    return CGWindowID(id)
  }

  private func selectorArguments(flag: String, value: String?) -> [String] {
    if let value {
      [flag, value]
    } else {
      [flag]
    }
  }
}
