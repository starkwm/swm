import Foundation
import StarkIPC

/// Unix socket IPC client for sending commands to the daemon.
public enum Client {
  /// Environment variable naming the configuration reload a command is sent from.
  ///
  /// `swm reload` sets it for the configuration file, so every `swm` command the file runs
  /// joins the reload. Programs the file leaves running inherit it too, which is why the
  /// daemon treats a token that is not the open reload as no token at all.
  public static let reloadTokenVariable = "SWM_RELOAD_TOKEN"

  /// Result of sending a command to the daemon.
  public struct SendResult {
    /// Whether the daemon accepted and completed the command.
    public let ok: Bool

    /// Response text intended for command-line output.
    public let outputMessage: String

    /// Machine-readable category of a failure reported by the daemon.
    public let errorCode: IPCErrorCode?

    public init(ok: Bool, outputMessage: String, errorCode: IPCErrorCode? = nil) {
      self.ok = ok
      self.outputMessage = outputMessage
      self.errorCode = errorCode
    }
  }

  /// Send a command request and wait for a response from the daemon.
  public static func send(domain: CommandDomain, args: [String]) -> SendResult {
    send(domain: domain, args: args, exchange: { try exchange($0) })
  }

  /// Send a command using an injected request/response exchange.
  ///
  /// A command sent from a configuration reload carries its token from the environment.
  static func send(
    domain: CommandDomain,
    args: [String],
    environment: [String: String] = ProcessInfo.processInfo.environment,
    exchange: (IPCRequest) throws -> IPCResponse
  ) -> SendResult {
    do {
      let token = environment[reloadTokenVariable].flatMap { $0.isEmpty ? nil : $0 }
      let request = try IPCRequest.make(domain: domain, arguments: args, transaction: token)
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
