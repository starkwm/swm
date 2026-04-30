import Foundation

struct QueryCommandHandler {
  func dispatch(_ request: IPCRequest) -> IPCResponse {
    do {
      switch request.command {
      case "--displays":
        return try response(id: request.id, payload: QueryDisplay.all())
      case "--windows":
        return try response(id: request.id, payload: QueryWindow.all())
      case "--spaces":
        return try response(id: request.id, payload: QuerySpace.all())
      default:
        return .failure(
          id: request.id,
          message: "unsupported query command: \(request.command)",
          errorCode: .unsupportedCommand
        )
      }
    } catch {
      return .failure(id: request.id, message: "error: \(error)", errorCode: .internalError)
    }
  }

  func response<T: Encodable>(id: String, payload: T) throws -> IPCResponse {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(payload)
    return .success(id: id, message: String(decoding: data, as: UTF8.self))
  }
}

extension KeyedEncodingContainer {
  mutating func encodeNilOrValue<T: Encodable>(_ value: T?, forKey key: Key) throws {
    if let value {
      try encode(value, forKey: key)
    } else {
      try encodeNil(forKey: key)
    }
  }
}
