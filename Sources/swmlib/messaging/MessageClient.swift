import Foundation
import Socket

public enum MessageClient {
    public static func send(message _: MessageDomain, args _: [String]) throws {
        let socket = try Socket.create(family: .unix)
        try socket.connect(to: try Daemon.socketFilePath())
    }
}
