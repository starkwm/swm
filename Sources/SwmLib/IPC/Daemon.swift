import Foundation
import StarkIPC

@MainActor
public final class Daemon {
  static let requestTimeout = Duration.milliseconds(4_500)

  private let path: String
  private let requestTimeout: Duration
  private let dispatch: @MainActor (IPCRequest) async -> IPCResponse
  private var server: SocketServer<IPCRequest, IPCResponse>?
  private var runID: UUID?
  private var requests = [UUID: Task<IPCResponse, Never>]()

  public convenience init(windows: Windows, spaces: Spaces, displays: Displays, tiling: Tiling) {
    let dispatcher = IPCCommandDispatcher(
      windows: windows,
      spaces: spaces,
      displays: displays,
      tiling: tiling
    )
    self.init(path: UnixSocket.filePath(), dispatch: dispatcher.dispatch)
  }

  init(
    path: String,
    requestTimeout: Duration = Daemon.requestTimeout,
    dispatch: @escaping @MainActor (IPCRequest) async -> IPCResponse
  ) {
    self.path = path
    self.requestTimeout = requestTimeout
    self.dispatch = dispatch
  }

  public func run() throws {
    guard server == nil else { return }

    let runID = UUID()
    let server = SocketServer<IPCRequest, IPCResponse>(
      path: path,
      serviceName: "swm",
      errorResponse: { error in
        .failure(id: "", message: "\(error)", errorCode: .invalidRequest)
      },
      handler: { [weak self] request in
        guard let self else {
          return SocketReply(
            IPCCommandError.internalError("daemon is shutting down").response(id: request.id)
          )
        }

        return await self.reply(to: request, runID: runID)
      }
    )

    try server.start()

    self.runID = runID
    self.server = server
  }

  public func shutdown() {
    runID = nil

    for request in requests.values { request.cancel() }
    requests.removeAll()

    server?.stop()
    server = nil
  }

  private func reply(to request: IPCRequest, runID: UUID) async -> SocketReply<IPCResponse> {
    guard self.runID == runID else {
      return SocketReply(
        IPCCommandError.internalError("daemon is shutting down").response(id: request.id)
      )
    }

    let dispatch = dispatch
    let task = Task {
      await IPCCommandError.catching(id: request.id) {
        guard !Task.isCancelled else {
          throw IPCCommandError.internalError("daemon is shutting down")
        }

        try request.validateVersion()
        log("daemon recv: \(request.domain.rawValue) \(request.command) \(request.args)")

        return await dispatch(request)
      }
    }

    let requestID = UUID()
    requests[requestID] = task
    defer { requests.removeValue(forKey: requestID) }

    let timeout = requestTimeout
    let deadline = Task {
      do { try await Task.sleep(for: timeout) } catch { return false }
      task.cancel()
      return true
    }

    let response = await withTaskCancellationHandler {
      await task.value
    } onCancel: {
      task.cancel()
    }
    deadline.cancel()

    if await deadline.value, !response.ok {
      log("daemon request timed out: \(request.domain.rawValue) \(request.command)", level: .warn)
      return SocketReply(
        IPCCommandError.internalError("request timed out and was cancelled").response(
          id: request.id
        )
      )
    }
    return SocketReply(response)
  }
}
