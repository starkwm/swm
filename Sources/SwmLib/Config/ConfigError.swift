enum ConfigError: Error {
  case fileDoesNotExist
  case unableToMakeExecutable
  case unableToExecute
  case configurationFailed(status: Int32)
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
    case .configurationFailed(let status):
      return "configuration file exited with status \(status)"
    }
  }
}
