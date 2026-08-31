/// Identifies one independently tiled display within a macOS Space.
struct TilingLayoutID: Hashable {
  /// WindowServer Space ID.
  let spaceID: UInt64

  /// Core Graphics display UUID.
  let displayID: String
}
