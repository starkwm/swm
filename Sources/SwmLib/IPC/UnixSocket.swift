import Foundation
import Socket

enum UnixSocket {
  static func filePath() -> String {
    return FileManager
      .default
      .temporaryDirectory
      .appendingPathComponent("swm_\(getuid()).sock", isDirectory: false)
      .path
  }

  static func removeStaleFileIfNeeded() throws {
    let path = filePath()

    guard FileManager.default.fileExists(atPath: path) else {
      return
    }

    let socket = try Socket.create(family: .unix)
    defer {
      socket.close()
    }

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
