public typealias WindowSpaceTarget = CyclicTarget

extension WindowSpaceTarget {
  func space(from sourceID: UInt64, spaces: [Space]) -> Space? {
    if case .index = self {
      return element(in: spaces, from: nil)
    }

    let desktops = spaces.filter { $0.type == .normal }
    return element(in: desktops, from: desktops.firstIndex { $0.id == sourceID })
  }
}
