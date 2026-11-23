import Foundation
import StarkIPC

public enum Client {
  public static let reloadTokenVariable = "SWM_RELOAD_TOKEN"

  public struct SendResult {
    public let ok: Bool

    public let outputMessage: String

    public let errorCode: IPCErrorCode?

    public init(ok: Bool, outputMessage: String, errorCode: IPCErrorCode? = nil) {
      self.ok = ok
      self.outputMessage = outputMessage
      self.errorCode = errorCode
    }
  }

  public static func send(_ command: IPCCommand) -> SendResult {
    send(command, exchange: { try exchange($0) })
  }

  static func send(
    _ command: IPCCommand,
    environment: [String: String] = ProcessInfo.processInfo.environment,
    exchange: (IPCRequest) throws -> IPCResponse
  ) -> SendResult {
    do {
      let token = environment[reloadTokenVariable].flatMap { $0.isEmpty ? nil : $0 }
      let request = IPCRequest(command: command, transaction: token)
      let response = try exchange(request)
      guard response.id == request.id else {
        throw IPCClientError.responseIDMismatch
      }

      return SendResult(
        ok: response.ok,
        outputMessage: response.outputMessage,
        errorCode: response.errorCode
      )
    } catch {
      let failure: IPCCommandError
      switch error {
      case let error as IPCCommandError: failure = error
      case let error as SocketError: failure = .internalError(error.localizedDescription)
      default: failure = .internalError("\(error)")
      }

      return SendResult(ok: false, outputMessage: failure.response(id: "").outputMessage)
    }
  }

  static func exchange(_ request: IPCRequest, path: String = UnixSocket.filePath()) throws
    -> IPCResponse
  {
    let client: SocketClient
    do {
      client = try SocketClient(path: path, serviceName: "swm", streaming: false)
    } catch {
      throw IPCClientError.daemonNotRunning
    }

    try client.send(request)
    return try client.receive(IPCResponse.self)
  }
}

enum IPCClientError: Error, Equatable, CustomStringConvertible {
  case daemonNotRunning

  case responseIDMismatch

  var description: String {
    switch self {
    case .daemonNotRunning:
      "daemon is not running"
    case .responseIDMismatch:
      "IPC response did not match its request"
    }
  }
}
