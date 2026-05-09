/// Server response sent over IPC.
struct IPCResponse: Codable, Equatable {
  /// Create a successful response.
  static func success(id: String, message: String) -> IPCResponse {
    IPCResponse(id: id, ok: true, message: message, errorCode: nil)
  }

  /// Create a failed response.
  static func failure(id: String, message: String, errorCode: IPCErrorCode) -> IPCResponse {
    IPCResponse(id: id, ok: false, message: message, errorCode: errorCode)
  }

  /// Request identifier this response belongs to.
  let id: String

  /// Whether the request completed successfully.
  let ok: Bool

  /// Response payload or human-readable error message.
  let message: String

  /// Machine-readable error code for failed responses.
  let errorCode: IPCErrorCode?

  /// Message formatted for command-line output.
  var outputMessage: String {
    if ok || message.hasPrefix("error: ") {
      return message
    }

    return "error: \(message)"
  }
}
