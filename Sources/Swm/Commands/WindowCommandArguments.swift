import ArgumentParser
import CoreGraphics
import SwmLib

struct WindowSelector: ParsableArguments {
  @Option(
    name: .long,
    help: "Window ID or recent; defaults to focused.",
    completion: .list(["recent"])
  )
  var window: WindowSelection?

  var selection: WindowSelection { window ?? .focused }
}

extension WindowSelection: ExpressibleByArgument {}

extension CyclicTarget: ExpressibleByArgument {}

enum FocusTarget: Equatable, ExpressibleByArgument {
  case direction(CardinalDirection)
  case order(CycleDirection)
  case master
  case window(WindowSelection)

  init?(argument: String) {
    if let direction = CardinalDirection(rawValue: argument) {
      self = .direction(direction)
    } else if let direction = CycleDirection(rawValue: argument) {
      self = .order(direction)
    } else if argument == "master" {
      self = .master
    } else if let selection = WindowSelection(argument: argument) {
      self = .window(selection)
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

  var layoutSelection: WindowLayoutSelection {
    switch self {
    case .on: .float
    case .off: .tile
    case .toggle: .toggle
    }
  }
}

struct WarpTarget: ExpressibleByArgument {
  let target: WindowTarget

  init?(argument: String) {
    if let direction = CardinalDirection(rawValue: argument) {
      target = .direction(direction)
    } else if let selection = WindowSelection(argument: argument) {
      target = .selected(selection)
    } else {
      return nil
    }
  }
}
