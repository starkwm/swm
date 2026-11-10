/// Error-code categories for IPC command failures.
enum IPCErrorCode: String, Codable, Equatable, Sendable {
  /// The request shape or arguments are invalid.
  case invalidRequest

  /// The requested command is not implemented for its domain.
  case unsupportedCommand

  /// The request failed while being processed.
  case internalError
}
