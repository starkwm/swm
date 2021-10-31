public enum DaemonError: Error {
    case userEnvVarMissing
    case unableToCreateSocket
    case unableToUnwrapSocket
    case unableToListenOnSocket
}

extension DaemonError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .userEnvVarMissing:
            return "USER environment variable is not set"
        case .unableToCreateSocket:
            return "unable to create listening socket"
        case .unableToUnwrapSocket:
            return "unable to unwrap listening socket"
        case .unableToListenOnSocket:
            return "unable to listen on listening socket"
        }
    }
}
