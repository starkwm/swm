import Foundation

struct IPCRequest: Codable, Equatable, Sendable {
  static let currentVersion = 1

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

  let version: Int

  let id: String

  let domain: CommandDomain

  let command: String

  let args: [String]

  let transaction: String?

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

  func validateVersion() throws {
    guard version == Self.currentVersion else {
      throw IPCCommandError.invalidRequest(
        "unsupported IPC request version: \(version); expected \(Self.currentVersion)"
      )
    }
  }
}
