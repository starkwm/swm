import Foundation
import Socket

public class Daemon {
    private static let maxReadBufferSize = 1024

    private let lockQueue = DispatchQueue(label: "io.tomb.swm")

    private var isRunning = false

    private var running: Bool {
        get {
            lockQueue.sync { self.isRunning }
        }
        set(newValue) {
            lockQueue.sync { self.isRunning = newValue }
        }
    }

    private var listen: Socket?

    public init() {}

    public func run() throws {
        do {
            try listen = Socket.create(family: .unix)
        } catch {
            throw DaemonError.unableToCreateSocket
        }

        guard let socket = listen else {
            throw DaemonError.unableToUnwrapSocket
        }

        do {
            let path = try Daemon.socketFilePath()
            try socket.listen(on: path)
        } catch {
            throw DaemonError.unableToListenOnSocket
        }

        running = true

        let queue = DispatchQueue.global(qos: .userInteractive)

        // swiftlint:disable:next unowned_variable_capture
        queue.async { [unowned self] in
            repeat {
                do {
                    let client = try socket.acceptClientConnection()
                    self.handle(socket: client)
                } catch {
                    fputs("error: accepting incoming client connection - \(error)", stderr)
                }
            } while self.running
        }
    }

    public func shutdown() {
        running = false

        try? FileManager.default.removeItem(atPath: try Daemon.socketFilePath())
    }

    private func handle(socket: Socket) {
        print("socket connected: \(socket.remotePath ?? "unkown")")
    }

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
