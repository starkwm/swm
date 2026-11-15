struct TilingLayoutID: Hashable, Comparable {
  let spaceID: UInt64

  let displayID: String

  static func < (lhs: Self, rhs: Self) -> Bool {
    (lhs.spaceID, lhs.displayID) < (rhs.spaceID, rhs.displayID)
  }
}
