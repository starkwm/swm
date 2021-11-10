enum UnixSocketError: Error {
    case userEnvVarMissing
}

extension UnixSocketError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .userEnvVarMissing:
            return "USER environment variable is not set"
        }
    }
}
