import Foundation

/// Loads and runs the user's swm configuration file.
public enum Config {
  /// Validate, prepare, and execute the configuration file at the given path.
  ///
  /// If the file is not executable by its owner, this marks it executable before
  /// launching it and waiting for it to exit.
  ///
  /// - Parameter path: Absolute or relative path to the configuration file.
  /// - Throws: A `ConfigError` when the file is missing, cannot be made
  ///   executable, cannot be launched, or exits with a non-zero status.
  public static func exec(path: String) throws {
    if !FileManager.default.fileExists(atPath: path) {
      throw ConfigError.fileDoesNotExist
    }

    try ensureOwnerExecutable(path: path)
    try runAndWait(path: path)
  }

  /// Add owner execute permission to the configuration file when it is missing.
  private static func ensureOwnerExecutable(path: String) throws {
    do {
      let attributes = try FileManager.default.attributesOfItem(atPath: path)

      guard let permissions = attributes[.posixPermissions] as? NSNumber else {
        throw ConfigError.unableToMakeExecutable
      }

      let currentPermissions = permissions.uint16Value
      let ownerExecute: UInt16 = 0o100

      if currentPermissions & ownerExecute == ownerExecute {
        return
      }

      try FileManager.default.setAttributes(
        [.posixPermissions: NSNumber(value: currentPermissions | ownerExecute)],
        ofItemAtPath: path
      )

      let updatedAttributes = try FileManager.default.attributesOfItem(atPath: path)

      guard
        let updatedPermissions = updatedAttributes[.posixPermissions] as? NSNumber,
        updatedPermissions.uint16Value & ownerExecute == ownerExecute
      else {
        throw ConfigError.unableToMakeExecutable
      }
    } catch {
      if let configError = error as? ConfigError {
        throw configError
      }

      throw ConfigError.unableToMakeExecutable
    }
  }

  /// Launch the configuration file and wait for it to finish.
  private static func runAndWait(path: String) throws {
    do {
      let proc = Foundation.Process()
      proc.executableURL = URL(fileURLWithPath: path)
      try proc.run()
      proc.waitUntilExit()

      if proc.terminationStatus != 0 {
        throw ConfigError.configurationFailed(status: proc.terminationStatus)
      }
    } catch {
      if let configError = error as? ConfigError {
        throw configError
      }

      throw ConfigError.unableToExecute
    }
  }
}

/// Errors raised while preparing or running the user's configuration file.
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
  /// User-facing explanation of the configuration failure.
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
