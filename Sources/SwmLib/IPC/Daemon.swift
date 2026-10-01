import Foundation
import StarkIPC

/// Adapts transport requests to the main-actor runtime.
@MainActor
public final class Daemon {
  private let path: String
  private let dispatch: @MainActor (IPCRequest) async -> IPCResponse
  private var server: SocketServer<IPCRequest, IPCResponse>?
  private var runID: UUID?
  private var requests = [UUID: Task<IPCResponse, Never>]()

  public convenience init(windows: Windows, spaces: Spaces, tiling: Tiling) {
    let dispatcher = IPCCommandDispatcher(windows: windows, spaces: spaces, tiling: tiling)
    self.init(path: UnixSocket.filePath(), dispatch: dispatcher.dispatch)
  }

  init(path: String, dispatch: @escaping @MainActor (IPCRequest) async -> IPCResponse) {
    self.path = path
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

  /// Admit work only for this run and cancel suspended commands when the daemon stops.
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

    return SocketReply(await task.value)
  }
}
