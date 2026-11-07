/// Space target for moving a window. Numeric indexes match `swm query spaces`.
typealias WindowSpaceTarget = CyclicTarget

extension WindowSpaceTarget {
  /// Cycle through normal desktops, or select a one-based query index for numeric targets.
  func space(from sourceID: UInt64, spaces: [Space]) -> Space? {
    if case .index = self {
      return element(in: spaces, from: nil)
    }

    let desktops = spaces.filter { $0.type == .normal }
    return element(in: desktops, from: desktops.firstIndex { $0.id == sourceID })
  }
}
