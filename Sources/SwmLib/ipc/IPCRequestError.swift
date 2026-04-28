enum IPCRequestError: Error {
  case missingCommand(MessageDomain)
}

extension IPCRequestError: CustomStringConvertible {
  var description: String {
    switch self {
    case .missingCommand(let domain):
      return "missing command for \(domain.rawValue)"
    }
  }
}
