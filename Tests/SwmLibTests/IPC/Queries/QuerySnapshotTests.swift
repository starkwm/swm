import CoreGraphics
import Foundation
import StarkSkyLight
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

  @Test("spaceSnapshot: derives Spaces and current Spaces, using Main for every screen")
  func spaceSnapshotDerivesSpacesAndCurrentSpacesUsingMainForEveryScreen() {
    let snapshot = QuerySnapshot(windows: Windows(workspace: Workspace(), focusedWindowID: nil))
    snapshot.arrangedScreens = [QueryTestScreen()]
    snapshot.spaceSnapshot = SpaceSnapshot(
      displays: [
        DisplaySpaces(
          id: DisplayID(rawValue: "Main"),
          spaces: [
            StarkSkyLight.Space(id: SpaceID(rawValue: 4), type: .desktop),
            StarkSkyLight.Space(id: SpaceID(rawValue: 7), type: .fullscreen),
          ],
          currentSpaceID: SpaceID(rawValue: 7)
        )
      ],
      activeSpaceID: SpaceID(rawValue: 7)
    )

    #expect(snapshot.spaces.map(\.id) == [4, 7])
    #expect(snapshot.spaces.map(\.type) == [.normal, .fullscreen])
    #expect(snapshot.activeSpaceID == 7)
    #expect(snapshot.displaySpaces == ["Main": [4, 7]])
    #expect(snapshot.currentSpaceByScreenID == ["Main": 7, "": 7])
  }

  @Test("spaceSnapshot: tolerates display identifiers that WindowServer repeats")
  func spaceSnapshotToleratesDisplayIdentifiersThatWindowServerRepeats() {
    let snapshot = QuerySnapshot(windows: Windows(workspace: Workspace(), focusedWindowID: nil))
    snapshot.arrangedScreens = []
    let display = { (id: String, spaceID: UInt64, current: UInt64?) in
      DisplaySpaces(
        id: DisplayID(rawValue: id),
        spaces: [StarkSkyLight.Space(id: SpaceID(rawValue: spaceID), type: .desktop)],
        currentSpaceID: current.map(SpaceID.init(rawValue:))
      )
    }
    snapshot.spaceSnapshot = SpaceSnapshot(
      displays: [
        display("display", 1, nil),
        display("display", 2, 2),
        display("DISPLAY", 3, 3),
      ],
      activeSpaceID: SpaceID(rawValue: 2)
    )

    #expect(snapshot.displaySpaces == ["display": [1, 2], "DISPLAY": [3]])
    #expect(snapshot.currentSpaceByScreenID == ["display": 2, "DISPLAY": 2])
  }
}
