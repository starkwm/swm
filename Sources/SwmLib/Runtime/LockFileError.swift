/// Errors raised while acquiring the runtime lock file.
enum LockFileError: Error {
  /// The lock file could not be opened or created.
  case failedToOpenFile

  /// The lock file could not be locked.
  case failedToLockFile
}

extension LockFileError: CustomStringConvertible {
  /// Human-readable lock-file failure description.
  var description: String {
    switch self {
    case .failedToOpenFile:
      return "failed to open lockfile"
    case .failedToLockFile:
      return "failed to lock lockfile"
    }
  }
}
