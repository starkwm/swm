public enum ProcessManagerError: Error, CustomStringConvertible {
  case accessFailed(String)

  public var description: String {
    switch self {
    case .accessFailed(let message):
      return message
    }
  }
}
