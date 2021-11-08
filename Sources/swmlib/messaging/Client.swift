import Foundation
import Socket

public enum Client {
    public static func send(message _: MessageDomain, args _: [String]) throws -> Int32 {
        let socket = try Socket.create(family: .unix)
        try socket.connect(to: try Daemon.socketFilePath())

        return EXIT_SUCCESS
    }
}
