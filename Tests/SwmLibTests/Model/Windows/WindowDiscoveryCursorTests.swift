import Testing

@testable import SwmLib

@Suite("WindowDiscoveryCursor")
struct WindowDiscoveryCursorTests {
  @Test("nextBatch: advances in bounded ranges")
  func nextBatchAdvancesInBoundedRanges() {
    var cursor = WindowDiscoveryCursor()

    #expect(cursor.nextBatch() == 0...4_095)
    #expect(cursor.nextBatch() == 4_096...8_191)
  }

  @Test("nextBatch: wraps after maximum token")
  func nextBatchWrapsAfterMaximumToken() {
    var cursor = WindowDiscoveryCursor()
    var lastBatch = cursor.nextBatch()

    while cursor.nextTokenID != 0 {
      lastBatch = cursor.nextBatch()
    }

    #expect(lastBatch.upperBound == WindowDiscoveryCursor.maximumTokenID)
    #expect(cursor.nextBatch().lowerBound == 0)
  }
}
