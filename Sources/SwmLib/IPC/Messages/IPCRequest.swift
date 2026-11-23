import Foundation

struct IPCRequest: Codable, Equatable, Sendable {
  static let currentVersion = 2

  let version: Int

  let id: String

  let command: IPCCommand

  let transaction: String?

  init(
    version: Int = IPCRequest.currentVersion,
    id: String = UUID().uuidString,
    command: IPCCommand,
    transaction: String? = nil
  ) {
    self.version = version
    self.id = id
    self.command = command
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
