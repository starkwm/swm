import Foundation

enum UnixSocket {
  static func filePath() -> String {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("swm_\(getuid()).sock", isDirectory: false)
      .path
  }
}
