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
      display: 1,
      space: 0,
      layer: nil,
      canMove: nil,
      canResize: nil,
      hasFocus: nil,
      hasAXReference: false,
      isNativeFullscreen: false,
      isVisible: false,
      isMinimized: false,
    )

    let object = try encodedObject(window)

    #expect(object["id"] as? Int == 1)
    #expect(object["pid"] is NSNull)
    #expect(object["app"] is NSNull)
    #expect(object["title"] is NSNull)
    #expect(object["frame"] is NSNull)
    #expect(object["role"] is NSNull)
    #expect(object["subrole"] is NSNull)
    #expect(object["layer"] is NSNull)
    #expect(object["can-move"] is NSNull)
    #expect(object["can-resize"] is NSNull)
    #expect(object["has-focus"] is NSNull)
    #expect(object["has-ax-reference"] as? Bool == false)
    #expect(object["display"] as? Int == 1)
    #expect(object["space"] as? Int == 0)
    #expect(object["is-native-fullscreen"] as? Bool == false)
    #expect(object["is-visible"] as? Bool == false)
    #expect(object["is-minimized"] as? Bool == false)
  }
}
