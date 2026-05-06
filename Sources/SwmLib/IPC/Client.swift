import Foundation
import Socket

public enum Client {
  public static func send(message: MessageDomain, args: [String]) {
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
        let stream = response.ok ? stdout : stderr

        fputs("\(response.outputMessage)\n", stream)
        exit(response.ok ? EXIT_SUCCESS : EXIT_FAILURE)
      }

      exit(EXIT_SUCCESS)
    } catch let error as IPCCommandError {
      let response = error.response(id: "")
      fputs("\(response.outputMessage)\n", stderr)
      exit(EXIT_FAILURE)
    } catch {
      let response = IPCCommandError.internalError("\(error)").response(id: "")
      fputs("\(response.outputMessage)\n", stderr)
      exit(EXIT_FAILURE)
    }
  }
}
