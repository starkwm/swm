public enum DaemonError: Error {
    case userEnvVarMissing
}

extension DaemonError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .userEnvVarMissing:
            return "USER environment variable is not set"
        }
    }
}
