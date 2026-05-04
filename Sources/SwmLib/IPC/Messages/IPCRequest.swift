import Foundation

struct IPCRequest: Codable, Equatable {
  static let currentVersion = 1

  static func make(domain: MessageDomain, arguments: [String]) throws -> IPCRequest {
    if domain == .query {
      let (command, selection) = try QuerySelection.parseRequest(arguments: arguments)
      return IPCRequest(domain: .query, command: command, args: selection.requestArguments)
    }

    guard let command = arguments.first else {
      throw IPCRequestError.missingCommand(domain)
    }

    return IPCRequest(
      domain: domain,
      command: command,
      args: Array(arguments.dropFirst())
    )
  }

  let version: Int
  let id: String
  let domain: MessageDomain
  let command: String
  let args: [String]

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
