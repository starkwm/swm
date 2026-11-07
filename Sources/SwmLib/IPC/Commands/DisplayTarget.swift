import CoreGraphics

/// Display target for focusing a display.
enum DisplayTarget: Equatable {
  /// A one-based index, or the display after or before the source display.
  case cyclic(CyclicTarget)
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
    if let target = CyclicTarget(argument: argument) {
      self = .cyclic(target)
      return
    }

    switch argument {
    case "first": self = .first
    case "last": self = .last
    case "recent": self = .recent
    case "mouse": self = .mouse
    default:
      guard let direction = CardinalDirection(rawValue: argument) else { return nil }
      self = .direction(direction)
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
    case .cyclic(let target):
      return target.element(in: displays, from: sourceIndex)?.id
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
