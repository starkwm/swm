import Foundation

/// Absolute rule target, independent of the window's current display.
enum RuleDisplayTarget: Equatable {
  case index(Int)
  case uuid(UUID)

  init?(argument: String) {
    if let index = Int(argument), index > 0 {
      self = .index(index)
    } else if let uuid = UUID(uuidString: argument) {
      self = .uuid(uuid)
    } else {
      return nil
    }
  }

  /// Resolve against display UUIDs in the same order as window display commands.
  func resolve(in displayIDs: [String]) -> String? {
    switch self {
    case .index(let index):
      return displayIDs.indices.contains(index - 1) ? displayIDs[index - 1] : nil
    case .uuid(let uuid):
      return displayIDs.first { UUID(uuidString: $0) == uuid }
    }
  }
}
