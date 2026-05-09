import Darwin
import Foundation

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

/// Per-user lock file used to prevent multiple swm daemon instances.
public enum LockFile {
  /// Create and lock the current user's runtime lock file.
  public static func acquire() throws {
    let handle = open(lockFilePath(), O_CREAT | O_WRONLY, 0o600)

    if handle == -1 {
      throw LockFileError.failedToOpenFile
    }

    var lockfd = flock()
    lockfd.l_start = 0
    lockfd.l_len = 0
    lockfd.l_pid = getpid()
    lockfd.l_type = Int16(F_WRLCK)
    lockfd.l_whence = Int16(SEEK_SET)

    if fcntl(handle, F_SETLK, &lockfd) == -1 {
      throw LockFileError.failedToLockFile
    }
  }

  /// Return the current user's lock-file path in the temporary directory.
  private static func lockFilePath() -> String {
    return FileManager
      .default
      .temporaryDirectory
      .appendingPathComponent("swm_\(getuid()).pid", isDirectory: false)
      .path
  }
}
