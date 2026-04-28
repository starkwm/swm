import Darwin
import Foundation

public enum LockFile {
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

  private static func lockFilePath() -> String {
    return FileManager
      .default
      .temporaryDirectory
      .appendingPathComponent("swm_\(getuid()).pid", isDirectory: false)
      .path
  }
}
