import Foundation
import StarkIPC

/// Unix socket IPC client for sending commands to the daemon.
public enum Client {
  /// Result of sending a command to the daemon.
  public struct SendResult {
    /// Whether the daemon accepted and completed the command.
    public let ok: Bool

    /// Response text intended for command-line output.
    public let outputMessage: String
  }

  /// Send a command request and wait for a response from the daemon.
  public static func send(domain: CommandDomain, args: [String]) -> SendResult {
    send(domain: domain, args: args, exchange: { try exchange($0) })
  }

  /// Send a command using an injected request/response exchange.
  static func send(
    domain: CommandDomain,
    args: [String],
    exchange: (IPCRequest) throws -> IPCResponse
  ) -> SendResult {
    do {
      let request = try IPCRequest.make(domain: domain, arguments: args)
      let response = try exchange(request)
      guard response.id == request.id else {
        throw IPCClientError.responseIDMismatch
      }

      return SendResult(ok: response.ok, outputMessage: response.outputMessage)
    } catch let error as IPCCommandError {
      let response = error.response(id: "")

      return SendResult(ok: false, outputMessage: response.outputMessage)
    } catch let error as SocketError {
      let response = IPCCommandError.internalError(error.localizedDescription).response(id: "")

      return SendResult(ok: false, outputMessage: response.outputMessage)
    } catch {
      let response = IPCCommandError.internalError("\(error)").response(id: "")

      return SendResult(ok: false, outputMessage: response.outputMessage)
    }
  }

  /// Exchange one request with the daemon over its Unix socket.
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

/// Client-side IPC transport and protocol failures.
enum IPCClientError: Error, Equatable, CustomStringConvertible {
  /// No daemon accepted the Unix socket connection.
  case daemonNotRunning

  /// The response identifier did not match the request identifier.
  case responseIDMismatch

  /// Human-readable client failure description.
  var description: String {
    switch self {
    case .daemonNotRunning:
      "daemon is not running"
    case .responseIDMismatch:
      "IPC response did not match its request"
    }
  }
}
