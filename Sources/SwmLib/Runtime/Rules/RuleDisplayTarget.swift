import Foundation

/// Absolute rule target, independent of the window's current display.
enum RuleDisplayTarget: Equatable {
  case index(Int)
  case uuid(UUID)

  init?(argument: String) {
    if let index = CyclicTarget.oneBasedIndex(from: argument) {
      self = .index(index)
    } else if let uuid = UUID(uuidString: argument) {
      self = .uuid(uuid)
    } else {
      return nil
    }
  }

  /// Resolve against display UUIDs in the same order as window display transfers.
  func resolve(in displayIDs: [String]) -> String? {
    switch self {
    case .index(let index):
      return displayIDs.element(atOneBasedIndex: index)
    case .uuid(let uuid):
      return displayIDs.first { UUID(uuidString: $0) == uuid }
    }
  }
}
