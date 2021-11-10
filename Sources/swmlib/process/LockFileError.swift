enum LockFileError: Error {
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
            return "failed to open lockfile"
        case .failedToLockFile:
            return "failed to lock lockfile"
        }
    }
}
