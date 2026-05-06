protocol IndexedFocusItem {
  var index: Int { get }
  var hasFocus: Bool { get }
}

enum FocusTargetValidator {
  static func validate<T: IndexedFocusItem>(
    target: String,
    items: [T],
    hasRecent: Bool,
    subject: String
  ) -> String? {
    switch target {
    case "recent":
      return hasRecent ? nil : "no recent \(subject)"

    case "prev", "next":
      return validAdjacentTarget(target, in: items) ? nil : "no focused \(subject)"

    default:
      guard let index = Int(target) else {
        return "invalid \(subject) focus target: \(target)"
      }

      return items.contains { $0.index == index } ? nil : "\(subject) index not found: \(index)"
    }
  }

  private static func validAdjacentTarget<T: IndexedFocusItem>(
    _ target: String,
    in items: [T]
  ) -> Bool {
    let arrangedItems = items.sorted { $0.index < $1.index }

    guard
      !arrangedItems.isEmpty,
      let currentItem = arrangedItems.first(where: \.hasFocus),
      let currentPosition = arrangedItems.firstIndex(where: { $0.index == currentItem.index })
    else {
      return false
    }

    let offset = target == "prev" ? -1 : 1
    let nextPosition = (currentPosition + offset + arrangedItems.count) % arrangedItems.count

    return arrangedItems.indices.contains(nextPosition)
  }
}

extension DisplaySerializer: IndexedFocusItem {}
extension SpaceSerializer: IndexedFocusItem {}
