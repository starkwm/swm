struct IPCRequest: Codable, Equatable {
  let message: MessageDomain
  let args: [String]
}
