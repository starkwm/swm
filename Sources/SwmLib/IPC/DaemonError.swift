enum DaemonError: Error {
  case unableToPrepareSocket(String)
  case unableToCreateSocket
  case unableToUnwrapSocket
  case unableToListenOnSocket
}

extension DaemonError: CustomStringConvertible {
  public var description: String {
    switch self {
    case .unableToPrepareSocket(let error):
      return "unable to prepare listening socket - \(error)"
    case .unableToCreateSocket:
      return "unable to create listening socket"
    case .unableToUnwrapSocket:
      return "unable to unwrap listening socket"
    case .unableToListenOnSocket:
      return "unable to listen on listening socket"
    }
  }
}
