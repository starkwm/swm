import CoreGraphics
import Foundation
import Testing

@testable import SwmLib

@Suite("QuerySnapshot")
@MainActor
struct QuerySnapshotTests {
  @Test("indexWindowInfo: indexes metadata by window id")
  func indexWindowInfoIndexesMetadataByWindowID() throws {
    let metadata: [[String: Any]] = [
      [
        kCGWindowNumber as String: NSNumber(value: UInt32(1)),
        kCGWindowOwnerName as String: "Terminal",
      ],
      [
        kCGWindowNumber as String: NSNumber(value: UInt32(42)),
        kCGWindowOwnerName as String: "Safari",
      ],
    ]

    let metadataByID = QuerySnapshot.indexWindowInfo(metadata)
    let info = try #require(metadataByID[42])

    #expect(info[kCGWindowOwnerName as String] as? String == "Safari")
    #expect(metadataByID[99] == nil)
  }
}
