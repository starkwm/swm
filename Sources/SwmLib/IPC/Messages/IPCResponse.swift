struct IPCResponse: Codable, Equatable {
  static func success(id: String, message: String) -> IPCResponse {
    IPCResponse(id: id, ok: true, message: message, errorCode: nil)
  }

  static func failure(id: String, message: String, errorCode: IPCErrorCode) -> IPCResponse {
    IPCResponse(id: id, ok: false, message: message, errorCode: errorCode)
  }

  let id: String
  let ok: Bool
  let message: String
  let errorCode: IPCErrorCode?

  var outputMessage: String {
    if ok || message.hasPrefix("error: ") {
      return message
    }

    return "error: \(message)"
  }
}
