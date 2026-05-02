import Foundation
import Testing

func encodedObject<T: Encodable>(_ value: T) throws -> [String: Any] {
  let data = try JSONEncoder().encode(value)
  let object = try JSONSerialization.jsonObject(with: data)
  return try #require(object as? [String: Any])
}
