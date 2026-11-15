import Darwin
import Foundation
import StarkIPC
import Testing

@testable import SwmLib

func runBlocking<Value: Sendable>(
  _ operation: @escaping @Sendable () throws -> Value
) async throws -> Value {
  try await withCheckedThrowingContinuation { continuation in
    DispatchQueue.global().async {
      continuation.resume(with: Result(catching: operation))
    }
  }
}

func legacyExchange(path: String, input: Data, endWriting: Bool = false) throws -> Data {
  let fd = try LocalSocket.connect(path: path)
  defer { close(fd) }
  try LocalSocket.send(input, to: fd)
  if endWriting { Darwin.shutdown(fd, SHUT_WR) }
  return try readToEOF(fd)
}

func readToEOF(_ fd: Int32) throws -> Data {
  var timeout = timeval(tv_sec: 7, tv_usec: 0)
  setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
  var data = Data()
  var buffer = [UInt8](repeating: 0, count: 8192)
  while true {
    let count = recv(fd, &buffer, buffer.count, 0)
    if count < 0 && errno == EINTR { continue }
    guard count >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    if count == 0 { return data }
    data.append(contentsOf: buffer.prefix(count))
  }
}

struct TestEndpoint: Sendable {
  let directory: URL
  var path: String { directory.appendingPathComponent("ipc.sock").path }

  init() throws {
    directory = URL(fileURLWithPath: "/tmp/swm-ipc-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
  }

  func remove() { try? FileManager.default.removeItem(at: directory) }
}
