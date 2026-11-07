/// A one-based index, or the item after or before a source item, wrapping at the ends.
enum CyclicTarget: Equatable {
  case index(Int)
  case next
  case previous

  /// Parse a positive one-based index.
  static func oneBasedIndex(from argument: String) -> Int? {
    guard let index = Int(argument), index > 0 else { return nil }
    return index
  }

  /// Parse `next`, `prev`, or a one-based index.
  init?(argument: String) {
    switch argument {
    case "next": self = .next
    case "prev": self = .previous
    default:
      guard let index = Self.oneBasedIndex(from: argument) else { return nil }
      self = .index(index)
    }
  }

  /// Select an item; `next` and `prev` step from `sourceIndex` and return nil without it.
  func element<Element>(in items: [Element], from sourceIndex: Int?) -> Element? {
    switch self {
    case .index(let index):
      return items.element(atOneBasedIndex: index)
    case .next, .previous:
      guard let sourceIndex, items.indices.contains(sourceIndex) else { return nil }
      let offset = self == .next ? 1 : -1
      return items[(sourceIndex + offset + items.count) % items.count]
    }
  }
}

extension Array {
  /// The element at a one-based index, or nil when the index is out of range.
  func element(atOneBasedIndex index: Int) -> Element? {
    indices.contains(index - 1) ? self[index - 1] : nil
  }
}
