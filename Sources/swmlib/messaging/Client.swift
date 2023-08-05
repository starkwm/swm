import Foundation
import Socket

public enum Client {
    public static func send(message: String, args: [String]) {
        do {
            let socket = try Socket.create(family: .unix)
            try socket.connect(to: UnixSocket.filePath())
            try socket.write(from: "\(message) \(args.joined(separator: " "))")
            exit(EXIT_SUCCESS)
        } catch {
            print("error: \(error)")
            exit(EXIT_FAILURE)
        }
    }
}
