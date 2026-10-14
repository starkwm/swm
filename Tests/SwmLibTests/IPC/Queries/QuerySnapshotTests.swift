import CoreGraphics
import Foundation
import Testing

@testable import SwmLib

@Suite("QuerySnapshot")
@MainActor
struct QuerySnapshotTests {
  @Test("indexWindowInfo: indexes metadata by window id")
  func indexWindowInfoIndexesMetadataByWindowId() throws {
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
  @Test("focusedWindowID: serializes one captured frontmost focus regardless of window order")
  func focusedWindowIDSerializesOneCapturedFrontmostFocusRegardlessOfWindowOrder() throws {
    for ids in [[CGWindowID(1), 2], [CGWindowID(2), 1]] {
      for focus in [CGWindowID(2), nil] {
        var focusReads = 0
        let snapshot = QuerySnapshot(
          windows: Windows(workspace: Workspace(), focusedWindowID: nil),
          focusedWindowID: {
            focusReads += 1
            return focus
          }
        )
        snapshot.windows = ids.map { Window(id: $0) }
        snapshot.screens = []
        snapshot.spaceIDsByWindowID = [:]
        snapshot.spaceIndexByID = [:]
        snapshot.nativeFullscreenSpaceIDs = []
        snapshot.windowInfoByID = [
          1: [kCGWindowOwnerName as String: "Background app"],
          2: [kCGWindowOwnerName as String: "Frontmost app"],
        ]
        let resolver = QueryResolver(
          displayProvider: {
            Issue.record("Loaded unrelated displays")
            return []
          },
          spaceProvider: {
            Issue.record("Loaded unrelated Spaces")
            return []
          },
          windowProvider: { WindowSerializer.all(snapshot: snapshot) }
        )
        guard case .one(let focused) = resolver.windows(for: .window(nil)),
          case .one(let explicit) = resolver.windows(for: .window(1))
        else {
          Issue.record("Expected singular window results")
          continue
        }
        #expect(focused?.id == focus)
        #expect(explicit?.id == 1)
        let serialized = resolver.windows
        for window in serialized {
          #expect(window.hasFocus == focus.map { $0 == window.id })
        }
        #expect(focusReads == 1)
      }
    }
  }

}
