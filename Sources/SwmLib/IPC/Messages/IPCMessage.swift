import Foundation
import Socket

enum IPCMessage {
  private static let delimiter = UInt8(ascii: "\n")
  private static let maxFrameSize = 64 * 1024
  private static let readBufferSize = 4 * 1024

  static func encode<T: Encodable>(_ value: T) throws -> Data {
    var data = try JSONEncoder().encode(value)
    data.append(delimiter)
    return data
  }

  static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
    var frame = data

    if frame.last == delimiter {
      frame.removeLast()
    }

    return try JSONDecoder().decode(type, from: frame)
  }

  static func readFrame(from socket: Socket) throws -> Data? {
    var frame = Data()

    while true {
      var chunk = Data(capacity: readBufferSize)
      let bytes = try socket.read(into: &chunk)

      if bytes <= 0 {
        return frame.isEmpty ? nil : frame
      }

      if let delimiterIndex = chunk.firstIndex(of: delimiter) {
        frame.append(chunk[..<delimiterIndex])

        if frame.count > maxFrameSize {
          throw UnixSocketError.frameTooLarge(maxFrameSize)
        }

        return frame
      }

      frame.append(chunk)

      if frame.count > maxFrameSize {
        throw UnixSocketError.frameTooLarge(maxFrameSize)
      }
    }
  }
}
