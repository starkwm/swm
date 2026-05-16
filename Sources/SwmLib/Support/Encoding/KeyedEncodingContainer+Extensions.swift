extension KeyedEncodingContainer {
  /// Encode an optional value while preserving explicit `null` keys.
  mutating func encodeNilOrValue<T: Encodable>(_ value: T?, forKey key: Key) throws {
    if let value {
      try encode(value, forKey: key)
    } else {
      try encodeNil(forKey: key)
    }
  }
}
