import Foundation

public enum Config {
  public static func execIfPresent(path: String) throws {
    guard FileManager.default.fileExists(atPath: path) else { return }
    try exec(path: path)
  }

  public static func exec(path: String, environment: [String: String] = [:]) throws {
    if !FileManager.default.fileExists(atPath: path) {
      throw ConfigError.fileDoesNotExist
    }

    try ensureOwnerExecutable(path: path)
    try runAndWait(path: path, environment: environment)
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
    } catch {
      throw error as? ConfigError ?? .unableToMakeExecutable
    }
  }

  private static func runAndWait(path: String, environment: [String: String]) throws {
    do {
      let proc = Foundation.Process()
      proc.executableURL = URL(fileURLWithPath: path)
      if !environment.isEmpty {
        proc.environment = ProcessInfo.processInfo.environment.merging(environment) { $1 }
      }
      try proc.run()
      proc.waitUntilExit()

      if proc.terminationStatus != 0 {
        throw ConfigError.configurationFailed(status: proc.terminationStatus)
      }
    } catch {
      throw error as? ConfigError ?? .unableToExecute
    }
  }
}

enum ConfigError: Error {
  case fileDoesNotExist

  case unableToMakeExecutable

  case unableToExecute

  case configurationFailed(status: Int32)
}

extension ConfigError: CustomStringConvertible {
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
