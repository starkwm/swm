import Foundation
import StarkSkyLight
import Testing

@testable import SwmLib

@Suite("SpaceSerializer")
struct SpaceSerializerTests {
  @Test(
    "all: preserves package Space types in query output",
    arguments: [
      (StarkSkyLight.SpaceType.desktop, "normal", false),
      (.fullscreen, "fullscreen", true), (.unknown(1), "unknown", false),
      (.unknown(99), "unknown", false),
    ]
  )
  @MainActor
  func allPreservesPackageSpaceTypesInQueryOutput(
    type: StarkSkyLight.SpaceType,
    expected: String,
    fullscreen: Bool
  ) throws {
    let snapshot = QuerySnapshot(windows: Windows(workspace: Workspace(), focusedWindowID: nil))
    snapshot.spaces = [Space(id: 42, type: SwmLib.SpaceType(type))]
    snapshot.displaySpaces = []
    snapshot.arrangedScreens = []
    snapshot.windows = []
    snapshot.spaceIDsByWindowID = [:]
    snapshot.activeSpaceID = 42
    snapshot.currentSpaceByScreenID = [:]
    let space = try #require(SpaceSerializer.all(snapshot: snapshot).first)
    #expect(space.type == expected)
    #expect(space.isNativeFullscreen == fullscreen)
  }

  @Test("all: derives window membership and shared visibility from the query snapshot")
  @MainActor
  func allDerivesWindowMembershipAndSharedVisibilityFromTheQuerySnapshot() {
    let snapshot = QuerySnapshot(windows: Windows(workspace: Workspace(), focusedWindowID: nil))
    snapshot.spaces = [Space(id: 42, type: .normal), Space(id: 43, type: .normal)]
    snapshot.displaySpaces = [WindowServerDisplaySpaces(id: "Main", spaces: [42, 43])]
    snapshot.arrangedScreens = [QueryTestScreen(), QueryTestScreen()]
    snapshot.windows = [Window(id: 1), Window(id: 2)]
    snapshot.spaceIDsByWindowID = [1: [42], 2: [42]]
    snapshot.activeSpaceID = 43
    snapshot.currentSpaceByScreenID = ["": 42]
    let spaces = SpaceSerializer.all(snapshot: snapshot)
    #expect(spaces.map(\.index) == [0, 1])
    #expect(spaces.map(\.windows) == [[1, 2], []])
    #expect(spaces.map(\.isVisible) == [true, false])
    #expect(spaces.map(\.hasFocus) == [false, true])
  }
}
