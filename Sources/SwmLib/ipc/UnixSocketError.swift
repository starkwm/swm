enum UnixSocketError: Error {
  case frameTooLarge(Int)
  case socketAlreadyInUse(String)
}

extension UnixSocketError: CustomStringConvertible {
  public var description: String {
    switch self {
    case .frameTooLarge(let maxBytes):
      return "IPC frame exceeded maximum size of \(maxBytes) bytes"
    case .socketAlreadyInUse(let path):
      return "socket is already in use at \(path)"
    }
  }
}
