import Foundation
import Socket

public struct Daemon {
    private static let maxReadBufferSize = 1024

    var listen: Socket?

    private static func socketFilePath() throws -> String {
        guard let user = ProcessInfo.processInfo.environment["USER"] else {
            throw DaemonError.userEnvVarMissing
        }

        return FileManager
            .default
            .temporaryDirectory
            .appendingPathComponent("swm_\(user).sock", isDirectory: false)
            .path
    }
}
