import Foundation
import Socket

public enum MessageClient {
    public static func send(message: MessageDomain, args: [String]) {
        do {
            let socket = try Socket.create(family: .unix)
            try socket.connect(to: try Daemon.socketFilePath())
            try socket.write(from: "\(message) \(args.joined(separator: " "))")
            exit(EXIT_SUCCESS)
        } catch {
            print("error: \(error)")
            exit(EXIT_FAILURE)
        }
    }
}
