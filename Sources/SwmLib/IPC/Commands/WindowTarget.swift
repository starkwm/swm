/// Parsed target for focusing or warping to a selected or directional window.
enum WindowTarget: Equatable {
  case selected(String?)
  case direction(CardinalDirection)

  /// Parse an optional window selector or cardinal direction.
  init?(arguments: [String]) {
    guard arguments.count <= 1 else { return nil }

    if let argument = arguments.first,
      let direction = CardinalDirection(rawValue: argument)
    {
      self = .direction(direction)
    } else {
      self = .selected(arguments.first)
    }
  }
}
