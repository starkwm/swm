import Darwin
import Foundation
import Socket

public class Daemon {
  private static let socketTimeout: UInt = 5_000

  private let lockQueue = DispatchQueue(label: "app.usestark.swm")
  private let dispatcher: IPCCommandDispatcher

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

  convenience init() {
    self.init(dispatcher: IPCCommandDispatcher())
  }

  convenience init(windowManager: WindowManager) {
    self.init(
      dispatcher: IPCCommandDispatcher(
        windowManager: windowManager,
        spaceManager: SpaceManager()
      )
    )
  }

  convenience init(windowManager: WindowManager, spaceManager: SpaceManager) {
    self.init(
      dispatcher: IPCCommandDispatcher(
        windowManager: windowManager,
        spaceManager: spaceManager
      )
    )
  }

  public convenience init(
    windowManager: WindowManager,
    spaceManager: SpaceManager,
    displayManager: DisplayManager
  ) {
    self.init(
      dispatcher: IPCCommandDispatcher(
        windowManager: windowManager,
        spaceManager: spaceManager
      )
    )
  }

  init(dispatcher: IPCCommandDispatcher) {
    self.dispatcher = dispatcher
  }

  public func run() throws {
    do {
      try UnixSocket.removeStaleFileIfNeeded()
    } catch {
      throw DaemonError.unableToPrepareSocket("\(error)")
    }

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

    let listeningSocket = UncheckedSocket(socket: socket)

    queue.async { [unowned self, listeningSocket] in
      repeat {
        do {
          let client = try listeningSocket.socket.acceptClientConnection()
          handle(socket: UncheckedSocket(socket: client))
        } catch {
          guard running else { break }
          log("accepting incoming client connection failed: \(error)", level: .error)
        }
      } while running
    }
  }

  public func shutdown() {
    running = false
    listen?.close()
    listen = nil

    try? FileManager.default.removeItem(atPath: UnixSocket.filePath())
  }

  private func handle(socket client: UncheckedSocket) {
    let queue = DispatchQueue.global(qos: .userInitiated)

    queue.async { [client] in
      let socket = client.socket

      defer {
        socket.close()
      }

      do {
        try socket.setReadTimeout(value: Daemon.socketTimeout)
        try socket.setWriteTimeout(value: Daemon.socketTimeout)

        guard self.isAuthorized(socket: socket) else {
          let response = IPCResponse.failure(
            id: "",
            message: "unauthorized IPC client",
            errorCode: .unauthorized
          )
          try socket.write(from: IPCMessage.encode(response))
          return
        }

        guard let data = try IPCMessage.readFrame(from: socket) else {
          return
        }

        let request = try IPCMessage.decode(IPCRequest.self, from: data)
        log("daemon recv: \(request.domain.rawValue) \(request.command) \(request.args)")

        let response = self.dispatcher.dispatch(request)
        try socket.write(from: IPCMessage.encode(response))
      } catch {
        log("could not receive data from socket: \(error)", level: .error)
        let response = IPCResponse.failure(
          id: "",
          message: "\(error)",
          errorCode: .invalidRequest
        )
        do {
          try socket.write(from: IPCMessage.encode(response))
        } catch {}
      }
    }
  }

  private func isAuthorized(socket: Socket) -> Bool {
    var uid: uid_t = 0
    var gid: gid_t = 0

    guard getpeereid(socket.socketfd, &uid, &gid) == 0 else {
      return false
    }

    return uid == getuid()
  }
}

extension Daemon: @unchecked Sendable {}

private struct UncheckedSocket: @unchecked Sendable {
  let socket: Socket
}
