public enum IPCErrorCode: String, Codable, Equatable, Sendable {
  case invalidRequest

  case unsupportedCommand

  case internalError
}
