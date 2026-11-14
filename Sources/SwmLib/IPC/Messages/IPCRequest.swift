import Foundation

/// Client request sent over IPC.
struct IPCRequest: Codable, Equatable, Sendable {
  /// Current request schema version.
  static let currentVersion = 1

  /// Build a request from a command domain and command-line style arguments.
  static func make(
    domain: CommandDomain,
    arguments: [String],
    transaction: String? = nil
  ) throws -> IPCRequest {
    guard let command = arguments.first else {
      throw IPCCommandError.invalidRequest("missing command for \(domain.rawValue)")
    }

    return IPCRequest(
      domain: domain,
      command: command,
      args: Array(arguments.dropFirst()),
      transaction: transaction
    )
  }

  /// Request schema version.
  let version: Int

  /// Unique request identifier echoed by the response.
  let id: String

  /// Command domain that should handle the request.
  let domain: CommandDomain

  /// Domain-specific command name or flag.
  let command: String

  /// Domain-specific command arguments.
  let args: [String]

  /// Configuration reload this request was sent from, if any.
  ///
  /// It is omitted from the encoded request when nil, so the schema is unchanged for
  /// requests sent outside a reload, and daemons that predate it ignore the key.
  let transaction: String?

  /// Create an IPC request.
  init(
    version: Int = IPCRequest.currentVersion,
    id: String = UUID().uuidString,
    domain: CommandDomain,
    command: String,
    args: [String],
    transaction: String? = nil
  ) {
    self.version = version
    self.id = id
    self.domain = domain
    self.command = command
    self.args = args
    self.transaction = transaction
  }

  /// Reject requests encoded for an unsupported IPC schema version.
  func validateVersion() throws {
    guard version == Self.currentVersion else {
      throw IPCCommandError.invalidRequest(
        "unsupported IPC request version: \(version); expected \(Self.currentVersion)"
      )
    }
  }
}
