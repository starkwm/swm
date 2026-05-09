import Foundation

/// A client request sent over IPC.
struct IPCRequest: Codable, Equatable {
  /// Current request schema version.
  static let currentVersion = 1

  /// Build a request from a command domain and command-line style arguments.
  static func make(domain: MessageDomain, arguments: [String]) throws -> IPCRequest {
    if domain == .query {
      let (command, selection) = try QuerySelection.parseRequest(arguments: arguments)

      return IPCRequest(domain: .query, command: command, args: selection.requestArguments)
    }

    guard let command = arguments.first else {
      throw IPCCommandError.invalidRequest("missing command for \(domain.rawValue)")
    }

    return IPCRequest(
      domain: domain,
      command: command,
      args: Array(arguments.dropFirst())
    )
  }

  /// Request schema version.
  let version: Int

  /// Unique request identifier echoed by the response.
  let id: String

  /// Command domain that should handle the request.
  let domain: MessageDomain

  /// Domain-specific command name or flag.
  let command: String

  /// Domain-specific command arguments.
  let args: [String]

  /// Create an IPC request.
  init(
    version: Int = IPCRequest.currentVersion,
    id: String = UUID().uuidString,
    domain: MessageDomain,
    command: String,
    args: [String]
  ) {
    self.version = version
    self.id = id
    self.domain = domain
    self.command = command
    self.args = args
  }
}
