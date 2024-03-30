import Foundation

public enum Config {
  public static func exec(path: String) throws {
    if !FileManager.default.fileExists(atPath: path) {
      throw ConfigError.fileDoesNotExist
    }

    if !ensureExecutable(path: path) {
      throw ConfigError.unableToMakeExecutable
    }

    do {
      let proc = Process()
      proc.executableURL = URL(fileURLWithPath: path)
      try proc.run()
    } catch {
      throw ConfigError.unableToExecute
    }
  }

  private static func ensureExecutable(path: String) -> Bool {
    if FileManager.default.isExecutableFile(atPath: path) {
      return true
    }

    do {
      try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
      return true
    } catch {
      return false
    }
  }
}
