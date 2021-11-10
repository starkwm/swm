import Foundation

enum UnixSocket {
    static func filePath() throws -> String {
        guard let user = ProcessInfo.processInfo.environment["USER"] else {
            throw UnixSocketError.userEnvVarMissing
        }

        return FileManager
            .default
            .temporaryDirectory
            .appendingPathComponent("swm_\(user).sock", isDirectory: false)
            .path
    }
}
