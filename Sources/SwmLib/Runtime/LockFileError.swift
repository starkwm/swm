enum LockFileError: Error {
  case failedToOpenFile
  case failedToLockFile
}

extension LockFileError: CustomStringConvertible {
  var description: String {
    switch self {
    case .failedToOpenFile:
      return "failed to open lockfile"
    case .failedToLockFile:
      return "failed to lock lockfile"
    }
  }
}
