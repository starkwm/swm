import CoreGraphics

/// Display target for focusing a display.
enum DisplayTarget: Equatable {
  case index(Int)
  case next
  case previous
  case first
  case last
  case recent
  case mouse
  case direction(CardinalDirection)

  /// Accepted target forms, for error messages.
  static let form =
    "a one-based display index, next, prev, first, last, recent, mouse, left, right, up, or down"

  /// Parse a display target.
  init?(argument: String) {
    switch argument {
    case "next": self = .next
    case "prev": self = .previous
    case "first": self = .first
    case "last": self = .last
    case "recent": self = .recent
    case "mouse": self = .mouse
    default:
      if let direction = CardinalDirection(rawValue: argument) {
        self = .direction(direction)
      } else if let index = Int(argument), index > 0 {
        self = .index(index)
      } else {
        return nil
      }
    }
  }

  /// Resolve the target display ID from displays in arrangement order.
  ///
  /// `next` and `prev` wrap around, matching `window move --display`.
  func displayID(
    from sourceID: String?,
    displays: [DisplayCandidate],
    recentID: String?,
    mouseLocation: CGPoint?
  ) -> String? {
    guard !displays.isEmpty else { return nil }
    let sourceIndex = displays.firstIndex { $0.id == sourceID }

    switch self {
    case .index(let index):
      guard displays.indices.contains(index - 1) else { return nil }
      return displays[index - 1].id
    case .next:
      guard let sourceIndex else { return nil }
      return displays[(sourceIndex + 1) % displays.count].id
    case .previous:
      guard let sourceIndex else { return nil }
      return displays[(sourceIndex - 1 + displays.count) % displays.count].id
    case .first:
      return displays.first?.id
    case .last:
      return displays.last?.id
    case .recent:
      return displays.first { $0.id == recentID }?.id
    case .mouse:
      guard let mouseLocation else { return nil }
      return displays.first { $0.frame.contains(mouseLocation) }?.id
    case .direction(let direction):
      guard let sourceIndex else { return nil }
      let framesByIndex = Dictionary(
        uniqueKeysWithValues: displays.enumerated().map { ($0.offset, $0.element.frame) }
      )
      return direction.neighbor(of: sourceIndex, in: framesByIndex).map { displays[$0].id }
    }
  }
}

/// A display's ID and frame in accessibility coordinates.
struct DisplayCandidate: Equatable {
  let id: String
  let frame: CGRect
}
