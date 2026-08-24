import Foundation
import Socket

/// Unix socket IPC client for sending commands to the daemon.
public enum Client {
  /// Result of sending a command to the daemon.
  public struct SendResult {
    /// Whether the daemon accepted and completed the command.
    public let ok: Bool

    /// Response text intended for command-line output.
    public let outputMessage: String?
  }

  /// Send a command request and wait for a response from the daemon.
  public static func send(message: MessageDomain, args: [String]) -> SendResult {
    send(message: message, args: args, exchange: exchange)
  }

  /// Send a command using an injected request/response exchange.
  static func send(
    message: MessageDomain,
    args: [String],
    exchange: (IPCRequest) throws -> IPCResponse?
  ) -> SendResult {
    do {
      let request = try IPCRequest.make(domain: message, arguments: args)
      guard let response = try exchange(request) else {
        throw IPCClientError.missingResponse
      }
      guard response.id == request.id else {
        throw IPCClientError.responseIDMismatch
      }

      return SendResult(ok: response.ok, outputMessage: response.outputMessage)
    } catch let error as IPCCommandError {
      let response = error.response(id: "")

      return SendResult(ok: false, outputMessage: response.outputMessage)
    } catch {
      let response = IPCCommandError.internalError("\(error)").response(id: "")

      return SendResult(ok: false, outputMessage: response.outputMessage)
    }
  }

  /// Exchange one request with the daemon over its Unix socket.
  private static func exchange(_ request: IPCRequest) throws -> IPCResponse? {
    let socket = try Socket.create(family: .unix)
    defer { socket.close() }

    try socket.setReadTimeout(value: UnixSocket.timeout)
    try socket.setWriteTimeout(value: UnixSocket.timeout)

    do {
      try socket.connect(to: UnixSocket.filePath())
    } catch {
      throw IPCClientError.daemonNotRunning
    }

    try socket.write(from: IPCMessage.encode(request))

    guard let data = try IPCMessage.readFrame(from: socket) else { return nil }
    return try IPCMessage.decode(IPCResponse.self, from: data)
  }
}

/// Client-side IPC transport and protocol failures.
enum IPCClientError: Error, Equatable, CustomStringConvertible {
  /// No daemon accepted the Unix socket connection.
  case daemonNotRunning

  /// The daemon closed the connection before sending a response.
  case missingResponse

  /// The response identifier did not match the request identifier.
  case responseIDMismatch

  /// Human-readable client failure description.
  var description: String {
    switch self {
    case .daemonNotRunning:
      "daemon is not running"
    case .missingResponse:
      "daemon closed the IPC connection without a response"
    case .responseIDMismatch:
      "IPC response did not match its request"
    }
  }
}
