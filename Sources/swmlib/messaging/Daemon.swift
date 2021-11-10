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
            try socket.listen(on: try UnixSocket.filePath())
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
                    fputs("error: accepting incoming client connection - \(error)\n", stderr)
                }
            } while self.running
        }
    }

    public func shutdown() {
        running = false

        if let path = try? UnixSocket.filePath() {
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    private func handle(socket: Socket) {
        let queue = DispatchQueue.global(qos: .userInitiated)

        queue.async {
            print("socket connected: \(socket.remotePath ?? "unkown")")

            do {
                var data = Data(capacity: Daemon.maxReadBufferSize)
                let bytes = try socket.read(into: &data)

                if bytes > 0 {
                    if let recv = String(data: data, encoding: .utf8) {
                        print("recv: \(recv)")
                    }
                }
            } catch {
                fputs("error: could not receive data from socket - \(error)\n", stderr)
            }

            socket.close()
        }
    }
}
