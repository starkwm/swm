import Foundation
import Testing

@testable import SwmLib

@Suite("DisplaySerializer")
struct DisplaySerializerTests {
  @Test("encode: uses kebab-case keys")
  func encodeUsesKebabCaseKeys() throws {
    let display = DisplaySerializer(
      id: 1,
      uuid: "display-uuid",
      index: 0,
      frame: FrameSerializer(.zero),
      spaces: [1],
      hasFocus: true
    )

    let object = try encodedObject(display)
    let spaces = try #require(object["spaces"] as? [Int])

    #expect(object["has-focus"] as? Bool == true)
    #expect(object["id"] as? Int == 1)
    #expect(object["uuid"] as? String == "display-uuid")
    #expect(spaces == [1])
  }
}
