import Foundation
import Socket

public enum Client {
  private static let maxReadBufferSize = 1024

  public static func send(message: String, args: [String]) {
    do {
      let socket = try Socket.create(family: .unix)

      try socket.connect(to: UnixSocket.filePath())
      try socket.write(from: "\(message) \(args.joined(separator: " "))")

      var data = Data(capacity: Client.maxReadBufferSize)
      let bytes = try socket.read(into: &data)

      if bytes > 0 {
        if let recv = String(data: data, encoding: .utf8) {
          print("recv: \(recv)")
        }
      }
      exit(EXIT_SUCCESS)
    } catch {
      print("error: \(error)")
      exit(EXIT_FAILURE)
    }
  }
}
