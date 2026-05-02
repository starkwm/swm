import Foundation
import Testing

@testable import SwmLib

@Suite("QueryDisplay")
struct QueryDisplayTests {
  @Test("encode: uses kebab-case keys")
  func encodeUsesKebabCaseKeys() throws {
    let display = QueryDisplay(
      id: "display-id",
      uuid: nil,
      index: 0,
      frame: QueryFrame(.zero),
      spaces: [1],
      hasFocus: true
    )

    let object = try encodedObject(display)
    let spaces = try #require(object["spaces"] as? [Int])

    #expect(object["has-focus"] as? Bool == true)
    #expect(object["uuid"] is NSNull)
    #expect(spaces == [1])
  }
}
