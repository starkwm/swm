import Darwin
import Foundation

public enum LockFile {
    public static func acquire() throws {
        let handle = try open(lockFilePath(), O_CREAT | O_WRONLY, 0o600)

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

    private static func lockFilePath() throws -> String {
        guard let user = ProcessInfo.processInfo.environment["USER"] else {
            throw LockFileError.userEnvVarMissing
        }

        return FileManager
            .default
            .temporaryDirectory
            .appendingPathComponent("swm_\(user).pid", isDirectory: false)
            .path
    }
}
