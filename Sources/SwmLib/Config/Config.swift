import Foundation

public enum Config {
  public static func exec(path: String) throws {
    try validateExists(path: path)
    try ensureOwnerExecutable(path: path)
    try runAndWait(path: path)
  }

  private static func validateExists(path: String) throws {
    if !FileManager.default.fileExists(atPath: path) {
      throw ConfigError.fileDoesNotExist
    }
  }

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
