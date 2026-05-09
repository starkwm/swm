/// Machine-readable categories for IPC command failures.
enum IPCErrorCode: String, Codable, Equatable {
  /// The request shape or arguments are invalid.
  case invalidRequest

  /// The requested command is not implemented for its domain.
  case unsupportedCommand

  /// The client is not allowed to perform the request.
  case unauthorized

  /// The request failed while being processed.
  case internalError
}
