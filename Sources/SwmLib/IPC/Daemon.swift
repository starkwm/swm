import Foundation
import StarkIPC

/// Adapts transport requests to the main-actor runtime.
@MainActor
public final class Daemon {
  private let path: String
  private let dispatch: @MainActor (IPCRequest) -> IPCResponse
  private var server: SocketServer<IPCRequest, IPCResponse>?
  private var runID: UUID?

  public convenience init(windows: Windows, spaces: Spaces, tiling: Tiling) {
    let dispatcher = IPCCommandDispatcher(windows: windows, spaces: spaces, tiling: tiling)
    self.init(path: UnixSocket.filePath(), dispatch: dispatcher.dispatch)
  }

  init(path: String, dispatch: @escaping @MainActor (IPCRequest) -> IPCResponse) {
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
        await MainActor.run {
          // A stopped server may still have handler tasks waiting for the main actor.
          // A new run must not admit work left over from a previous run.
          guard let self, self.runID == runID else {
            return SocketReply(
              IPCCommandError.internalError("daemon is shutting down").response(id: request.id)
            )
          }

          let response = IPCCommandError.catching(id: request.id) {
            try request.validateVersion()
            log("daemon recv: \(request.domain.rawValue) \(request.command) \(request.args)")
            return self.dispatch(request)
          }
          return SocketReply(response)
        }
      }
    )
    try server.start()
    self.runID = runID
    self.server = server
  }

  public func shutdown() {
    runID = nil
    server?.stop()
    server = nil
  }
}
