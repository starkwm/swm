import Darwin
import Testing

@testable import SwmLib

@Suite("UnixSocket")
struct UnixSocketTests {
  @Test("socket path uses uid")
  func socketPathUsesUID() {
    #expect(UnixSocket.filePath().hasSuffix("swm_\(getuid()).sock"))
  }
}
