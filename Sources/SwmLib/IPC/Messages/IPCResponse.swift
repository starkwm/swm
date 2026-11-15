import Foundation

struct IPCResponse: Codable, Equatable, Sendable {
  static func success(id: String, message: String) -> IPCResponse {
    IPCResponse(id: id, ok: true, message: message, errorCode: nil)
  }

  static func acknowledged(id: String) -> IPCResponse {
    .success(id: id, message: "")
  }

  static func failure(id: String, message: String, errorCode: IPCErrorCode) -> IPCResponse {
    IPCResponse(id: id, ok: false, message: message, errorCode: errorCode)
  }

  static func json<T: Encodable>(id: String, payload: T) throws -> IPCResponse {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(payload)
    return .success(id: id, message: String(decoding: data, as: UTF8.self))
  }

  let id: String

  let ok: Bool

  let message: String

  let errorCode: IPCErrorCode?

  var outputMessage: String {
    ok ? message : "Error: \(message)"
  }
}
