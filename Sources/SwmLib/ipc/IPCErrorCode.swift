enum IPCErrorCode: String, Codable, Equatable {
  case invalidRequest
  case unsupportedCommand
  case unauthorized
  case internalError
}
