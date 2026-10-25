/// Identifies one independently tiled display within a macOS Space.
struct TilingLayoutID: Hashable, Comparable {
  /// WindowServer Space ID.
  let spaceID: UInt64

  /// Core Graphics display UUID.
  let displayID: String

  /// Order by Space, then display, for deterministic reconciliation and frame application.
  static func < (lhs: Self, rhs: Self) -> Bool {
    (lhs.spaceID, lhs.displayID) < (rhs.spaceID, rhs.displayID)
  }
}
