/// Errors raised while preparing or reading the Unix domain socket transport.
enum UnixSocketError: Error {
  /// Newline-delimited IPC frame exceeded the maximum allowed byte count.
  case frameTooLarge(Int)

  /// Live process is already listening on the socket path.
  case socketAlreadyInUse(String)
}

extension UnixSocketError: CustomStringConvertible {
  /// Human-readable socket failure description.
  var description: String {
    switch self {
    case .frameTooLarge(let maxBytes):
      return "IPC frame exceeded maximum size of \(maxBytes) bytes"
    case .socketAlreadyInUse(let path):
      return "socket is already in use at \(path)"
    }
  }
}
