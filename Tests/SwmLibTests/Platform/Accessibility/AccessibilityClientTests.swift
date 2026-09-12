import ApplicationServices
import Foundation
import Testing

@testable import SwmLib

@Suite("AccessibilityClient")
struct AccessibilityClientTests {
  @Test("frame: decodes batched position and size")
  func decodesFrame() throws {
    let values = try frameValues()
    #expect(
      AccessibilityClient.frame(from: values)
        == CGRect(x: -200, y: 50, width: 640, height: 480)
    )
  }

  @Test(
    "frame: rejects missing, unsupported, and incorrectly typed attributes",
    arguments: ["empty", "missing", "null", "string", "error", "swapped", "extra"]
  )
  func rejectsInvalidFrame(kind: String) throws {
    var values = try frameValues()
    switch kind {
    case "empty": values = []
    case "missing": values.removeLast()
    case "null": values[0] = NSNull()
    case "string": values[1] = "unsupported" as NSString
    case "error":
      var error = AXError.attributeUnsupported
      values[1] = try #require(AXValueCreate(.axError, &error))
    case "swapped": values.reverse()
    default: values.append(NSNull())
    }

    #expect(AccessibilityClient.frame(from: values) == nil)
  }

  private func frameValues() throws -> [AnyObject] {
    var point = CGPoint(x: -200, y: 50)
    var size = CGSize(width: 640, height: 480)
    return [
      try #require(AXValueCreate(.cgPoint, &point)),
      try #require(AXValueCreate(.cgSize, &size)),
    ]
  }
}
