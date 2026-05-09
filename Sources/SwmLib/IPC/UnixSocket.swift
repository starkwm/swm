import Foundation
import Socket

/// Helpers for the per-user Unix domain socket used by IPC.
enum UnixSocket {
  /// Return the current user's socket path in the temporary directory.
  static func filePath() -> String {
    return FileManager
      .default
      .temporaryDirectory
      .appendingPathComponent("swm_\(getuid()).sock", isDirectory: false)
      .path
  }

  /// Remove a stale socket file unless another process is actively listening on it.
  static func removeStaleFileIfNeeded() throws {
    let path = filePath()

    guard FileManager.default.fileExists(atPath: path) else {
      return
    }

    let socket = try Socket.create(family: .unix)
    defer { socket.close() }

    do {
      try socket.connect(to: path)
      throw UnixSocketError.socketAlreadyInUse(path)
    } catch let error as UnixSocketError {
      throw error
    } catch {
      try FileManager.default.removeItem(atPath: path)
    }
  }
}
