public enum LockFileError: Error {
    case userEnvVarMissing
    case failedToOpenFile
    case failedToLockFile
}

extension LockFileError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .userEnvVarMissing:
            return "USER environment variable is not set"
        case .failedToOpenFile:
            return "Failed to open lockfile"
        case .failedToLockFile:
            return "Failed to lock lockfile"
        }
    }
}
