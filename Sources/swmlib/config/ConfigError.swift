enum ConfigError: Error {
  case fileDoesNotExist
  case unableToMakeExecutable
  case unableToExecute
}

extension ConfigError: CustomStringConvertible {
  public var description: String {
    switch self {
    case .fileDoesNotExist:
      return "configuration file does not exist"
    case .unableToMakeExecutable:
      return "unable to mark the configuration file as executable"
    case .unableToExecute:
      return "unable to execute the configuration file"
    }
  }
}
