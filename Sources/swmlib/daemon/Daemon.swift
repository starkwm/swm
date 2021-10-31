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
        let queue = DispatchQueue.global(qos: .userInteractive)

        queue.async { [weak self] in
            do {
                try listen = Socket.create(family: .unix)

                guard let socket = self.listen else {
                    print("unable to unwrap socket")
                    return
                }

                try socket.listen(on: try Daemon.socketFilePath())

                self.running = true

                repeat {
                    let client = try socket.acceptClientConnection()
                    self.handle(socket: client)
                } while self.running
            } catch {
                print("error: \(error)")
                return
            }
        }

        listen?.close()
    }

    public func shutdown() throws {
        running = false

        try FileManager.default.removeItem(atPath: try Daemon.socketFilePath())
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
