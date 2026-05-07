import Foundation
import Socket

public enum Client {
  public struct SendResult {
    public let ok: Bool
    public let outputMessage: String?
  }

  public static func send(message: MessageDomain, args: [String]) -> SendResult {
    do {
      let request = try IPCRequest.make(domain: message, arguments: args)

      let socket = try Socket.create(family: .unix)
      defer { socket.close() }

      try socket.setReadTimeout(value: 5_000)
      try socket.setWriteTimeout(value: 5_000)
      try socket.connect(to: UnixSocket.filePath())
      try socket.write(from: IPCMessage.encode(request))

      if let data = try IPCMessage.readFrame(from: socket) {
        let response = try IPCMessage.decode(IPCResponse.self, from: data)

        return SendResult(ok: response.ok, outputMessage: response.outputMessage)
      }

      return SendResult(ok: true, outputMessage: nil)
    } catch let error as IPCCommandError {
      let response = error.response(id: "")

      return SendResult(ok: false, outputMessage: response.outputMessage)
    } catch {
      let response = IPCCommandError.internalError("\(error)").response(id: "")

      return SendResult(ok: false, outputMessage: response.outputMessage)
    }
  }
}
