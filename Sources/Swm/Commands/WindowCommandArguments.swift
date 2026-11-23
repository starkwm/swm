import ArgumentParser
import SwmLib

struct WindowSelector: ParsableArguments {
  @Option(
    name: .long,
    help: "Window ID or recent; defaults to focused.",
    completion: .list(["recent"])
  )
  var window: String?

  var arguments: [String] { window.map { [$0] } ?? [] }
}

struct WindowIdentityTarget: ExpressibleByArgument {
  let value: String

  init?(argument: String) {
    guard argument == "recent" || UInt32(argument).map({ $0 > 0 }) == true else { return nil }
    value = argument
  }
}

enum FocusTarget: Equatable, ExpressibleByArgument {
  case direction(CardinalDirection)
  case order(CycleDirection)
  case master
  case window(String)

  init?(argument: String) {
    if let direction = CardinalDirection(rawValue: argument) {
      self = .direction(direction)
    } else if let direction = CycleDirection(rawValue: argument) {
      self = .order(direction)
    } else if argument == "master" {
      self = .master
    } else if argument == "recent" || UInt32(argument) != nil {
      self = .window(argument)
    } else {
      return nil
    }
  }
}

enum SwapTarget: Equatable, ExpressibleByArgument {
  case direction(CardinalDirection)
  case order(CycleDirection)
  case master

  init?(argument: String) {
    switch FocusTarget(argument: argument) {
    case .direction(let direction): self = .direction(direction)
    case .order(let direction): self = .order(direction)
    case .master: self = .master
    case .window, nil: return nil
    }
  }
}

enum WindowFloatState: String, CaseIterable, ExpressibleByArgument {
  case on, off, toggle

  var layoutValue: String {
    switch self {
    case .on: "float"
    case .off: "tile"
    case .toggle: "toggle"
    }
  }
}

struct WarpTarget: ExpressibleByArgument {
  let value: String

  init?(argument: String) {
    guard
      CardinalDirection(rawValue: argument) != nil
        || argument == "recent" || UInt32(argument).map({ $0 > 0 }) == true
    else { return nil }
    value = argument
  }
}

struct WindowTransferTarget: ExpressibleByArgument {
  static let keywords = ["next", "prev"]

  let value: String

  init?(argument: String) {
    guard
      Self.keywords.contains(argument)
        || Int(argument).map({ $0 > 0 }) == true
    else { return nil }
    value = argument
  }
}
