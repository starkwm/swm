/// Cursor for bounded passes over private accessibility remote-token IDs.
struct WindowDiscoveryCursor: Equatable {
  static let batchSize = 4_096
  static let maximumTokenID = 0x7fff

  private(set) var nextTokenID = 0

  /// Return the next bounded token range and advance, wrapping after the maximum.
  mutating func nextBatch() -> ClosedRange<Int> {
    let start = nextTokenID
    let end = min(start + Self.batchSize - 1, Self.maximumTokenID)
    nextTokenID = end == Self.maximumTokenID ? 0 : end + 1
    return start...end
  }
}
