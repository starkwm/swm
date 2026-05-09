/// Errors that can occur while preparing or running the user's configuration file.
enum ConfigError: Error {
  /// The configuration file path does not exist.
  case fileDoesNotExist

  /// The configuration file could not be marked executable by its owner.
  case unableToMakeExecutable

  /// The configuration file could not be launched.
  case unableToExecute

  /// The configuration file launched but exited unsuccessfully.
  case configurationFailed(status: Int32)
}

extension ConfigError: CustomStringConvertible {
  /// A user-facing explanation of the configuration failure.
  var description: String {
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
