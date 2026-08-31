import AppKit

/// Display target for moving a window.
struct WindowDisplayTarget: Equatable {
  private enum Value: Equatable {
    case next
    case previous
    case index(Int)
  }

  private let value: Value

  /// Parse a display target.
  init?(argument: String) {
    switch argument {
    case "next":
      value = .next
    case "prev", "previous":
      value = .previous
    default:
      guard let index = Int(argument), index > 0 else { return nil }
      value = .index(index)
    }
  }

  /// Resolve the target display from the available screens.
  func screen(from source: NSScreen, screens: [NSScreen]) -> NSScreen? {
    guard !screens.isEmpty else { return nil }

    switch value {
    case .next:
      guard let sourceIndex = screens.firstIndex(where: { $0.uuid == source.uuid }) else {
        return nil
      }
      return screens[(sourceIndex + 1) % screens.count]
    case .previous:
      guard let sourceIndex = screens.firstIndex(where: { $0.uuid == source.uuid }) else {
        return nil
      }
      return screens[(sourceIndex - 1 + screens.count) % screens.count]
    case .index(let index):
      let arrayIndex = index - 1
      guard screens.indices.contains(arrayIndex) else { return nil }
      return screens[arrayIndex]
    }
  }
}
