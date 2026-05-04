import Foundation
import Testing

@testable import SwmLib

@Suite("SpaceSerializer")
struct SpaceSerializerTests {
  @Test("encode: uses window IDs")
  func encodeUsesWindowIDs() throws {
    let space = SpaceSerializer(
      id: 1,
      uuid: nil,
      index: 0,
      label: nil,
      type: "normal",
      display: nil,
      windows: [1],
      hasFocus: false,
      isVisible: false,
      isNativeFullscreen: false
    )

    let object = try encodedObject(space)
    let windows = try #require(object["windows"] as? [Int])

    #expect(windows == [1])
    #expect(object["first-window"] == nil)
    #expect(object["last-window"] == nil)
    #expect(object["has-focus"] as? Bool == false)
    #expect(object["is-native-fullscreen"] as? Bool == false)
  }

  @Test("encode: allows empty window array")
  func encodeAllowsEmptyWindowArray() throws {
    let space = SpaceSerializer(
      id: 1,
      uuid: nil,
      index: 0,
      label: nil,
      type: "normal",
      display: nil,
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
}
