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
    let object = try encodedObject(space)
    #expect(object["type"] as? String == expected)
    #expect(object["is-native-fullscreen"] as? Bool == fullscreen)
    #expect(object["has-focus"] as? Bool == true)
  }

  @Test("encode: uses window IDs")
  func encodeUsesWindowIDs() throws {
    let space = SpaceSerializer(
      id: 1,
      index: 0,
      type: "normal",
      displays: [1],
      windows: [1],
      hasFocus: false,
      isVisible: false,
      isNativeFullscreen: false
    )

    let object = try encodedObject(space)
    let windows = try #require(object["windows"] as? [Int])

    #expect(windows == [1])
    #expect(object["displays"] as? [Int] == [1])
    #expect(object["display"] == nil)
    #expect(object["first-window"] == nil)
    #expect(object["last-window"] == nil)
    #expect(object["has-focus"] as? Bool == false)
    #expect(object["is-native-fullscreen"] as? Bool == false)
  }

  @Test("encode: allows empty window array")
  func encodeAllowsEmptyWindowArray() throws {
    let space = SpaceSerializer(
      id: 1,
      index: 0,
      type: "normal",
      displays: [],
      windows: [],
      hasFocus: false,
      isVisible: false,
      isNativeFullscreen: false
    )

    let object = try encodedObject(space)
    let windows = try #require(object["windows"] as? [Any])

    #expect(windows.isEmpty)
    #expect(object["first-window"] == nil)
    #expect(object["last-window"] == nil)
  }

  @Test("encode: uses displays for shared spaces")
  func encodeUsesDisplaysForSharedSpaces() throws {
    let space = SpaceSerializer(
      id: 1,
      index: 0,
      type: "normal",
      displays: [1, 2],
      windows: [],
      hasFocus: false,
      isVisible: true,
      isNativeFullscreen: false
    )

    let object = try encodedObject(space)
    let displays = try #require(object["displays"] as? [Int])

    #expect(displays == [1, 2])
    #expect(object["display"] == nil)
  }
}
