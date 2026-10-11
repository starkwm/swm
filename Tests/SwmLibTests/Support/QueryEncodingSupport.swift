import AppKit
import Foundation
import Testing

func encodedObject<T: Encodable>(_ value: T) throws -> [String: Any] {
  let data = try JSONEncoder().encode(value)
  let object = try JSONSerialization.jsonObject(with: data)
  return try #require(object as? [String: Any])
}

/// Screen geometry independent of the test host's connected displays.
final class QueryTestScreen: NSScreen {
  override var deviceDescription: [NSDeviceDescriptionKey: Any] { [:] }

  override var frame: NSRect {
    NSRect(x: 0, y: 0, width: 1920, height: 1080)
  }
}
