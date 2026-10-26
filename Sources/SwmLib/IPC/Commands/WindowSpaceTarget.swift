/// Space target for moving a window. Numeric indexes match `swm query spaces`.
enum WindowSpaceTarget: Equatable {
  case index(Int)
  case next
  case previous

  init?(argument: String) {
    switch argument {
    case "next": self = .next
    case "prev", "previous": self = .previous
    default:
      guard let index = Int(argument), index > 0 else { return nil }

      self = .index(index)
    }
  }

  /// Cycle through normal desktops, or select a one-based query index for numeric targets.
  func space(from sourceID: UInt64, spaces: [Space]) -> Space? {
    switch self {
    case .index(let index):
      guard index > 0, spaces.indices.contains(index - 1) else { return nil }

      return spaces[index - 1]

    case .next, .previous:
      let desktops = spaces.filter { $0.type == .normal }

      guard let sourceIndex = desktops.firstIndex(where: { $0.id == sourceID }) else {
        return nil
      }

      let offset = self == .next ? 1 : -1

      return desktops[(sourceIndex + offset + desktops.count) % desktops.count]
    }
  }
}
