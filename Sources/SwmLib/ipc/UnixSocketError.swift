enum UnixSocketError: Error {
  case userEnvVarMissing
  case frameTooLarge(Int)
}

extension UnixSocketError: CustomStringConvertible {
  public var description: String {
    switch self {
    case .userEnvVarMissing:
      return "USER environment variable is not set"
    case .frameTooLarge(let maxBytes):
      return "IPC frame exceeded maximum size of \(maxBytes) bytes"
    }
  }
}
