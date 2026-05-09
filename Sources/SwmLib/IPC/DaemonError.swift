/// Errors raised while starting the IPC daemon.
enum DaemonError: Error {
  /// The daemon could not remove or validate the socket path before listening.
  case unableToPrepareSocket(String)

  /// The daemon could not create a Unix socket.
  case unableToCreateSocket

  /// The listening socket was unexpectedly unavailable after creation.
  case unableToUnwrapSocket

  /// The daemon could not listen on the Unix socket path.
  case unableToListenOnSocket
}

extension DaemonError: CustomStringConvertible {
  /// Human-readable daemon startup failure description.
  var description: String {
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
