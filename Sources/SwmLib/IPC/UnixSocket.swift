import Foundation

/// The legacy endpoint name remains stable for existing clients.
enum UnixSocket {
  static func filePath() -> String {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("swm_\(getuid()).sock", isDirectory: false)
      .path
  }
}
