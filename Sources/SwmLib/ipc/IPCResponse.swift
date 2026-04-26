struct IPCResponse: Codable, Equatable {
  let ok: Bool
  let message: String

  static func success(_ message: String) -> IPCResponse {
    IPCResponse(ok: true, message: message)
  }

  static func failure(_ message: String) -> IPCResponse {
    IPCResponse(ok: false, message: message)
  }
}
