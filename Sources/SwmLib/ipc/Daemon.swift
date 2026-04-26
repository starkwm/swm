import Foundation
import Socket

public class Daemon {
  private let lockQueue = DispatchQueue(label: "app.usestark.swm")

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
      try socket.listen(on: UnixSocket.filePath())
    } catch {
      throw DaemonError.unableToListenOnSocket
    }

    running = true

    let queue = DispatchQueue.global(qos: .userInteractive)

    queue.async { [unowned self] in
      repeat {
        do {
          let client = try socket.acceptClientConnection()
          handle(socket: client)
        } catch {
          fputs("error: accepting incoming client connection - \(error)\n", stderr)
        }
      } while running
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
      print("socket connected: \(socket.remotePath ?? "unknown")")
      defer {
        socket.close()
      }

      do {
        guard let data = try IPCMessage.readFrame(from: socket) else {
          return
        }

        let request = try IPCMessage.decode(IPCRequest.self, from: data)
        print("daemon recv: \(request.message.rawValue) \(request.args)")

        let response = IPCResponse.success("received \(request.message.rawValue)")
        try socket.write(from: IPCMessage.encode(response))
      } catch {
        fputs("error: could not receive data from socket - \(error)\n", stderr)
        let response = IPCResponse.failure("error: \(error)")
        do {
          try socket.write(from: IPCMessage.encode(response))
        } catch {}
      }
    }
  }
}
