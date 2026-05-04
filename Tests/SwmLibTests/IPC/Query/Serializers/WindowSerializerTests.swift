import Foundation
import Testing

@testable import SwmLib

@Suite("WindowSerializer")
struct WindowSerializerTests {
  @Test("encode: uses nullable kebab-case keys")
  func encodeUsesNullableKebabCaseKeys() throws {
    let window = WindowSerializer(
      id: 1,
      pid: nil,
      app: nil,
      title: nil,
      frame: nil,
      role: nil,
      subrole: nil,
      display: "display-0",
      space: 0,
      layer: nil,
      subLayer: nil,
      canMove: nil,
      canResize: nil,
      hasFocus: nil,
      hasAXReference: false,
      isNativeFullscreen: nil,
      isVisible: nil,
      isMinimized: nil,
      isFloating: nil
    )

    let object = try encodedObject(window)

    #expect(object["has-ax-reference"] as? Bool == false)
    #expect(object["display"] as? String == "display-0")
    #expect(object["space"] as? Int == 0)
    #expect(object["is-native-fullscreen"] is NSNull)
    #expect(object["root-window"] == nil)
    #expect(object["level"] == nil)
    #expect(object["sub-level"] == nil)
    #expect(object["opacity"] == nil)
    #expect(object["has-shadow"] == nil)
    #expect(object["has-parent-zoom"] == nil)
    #expect(object["has-fullscreen-zoom"] == nil)
    #expect(object["is-hidden"] == nil)
    #expect(object["is-sticky"] == nil)
  }
}
