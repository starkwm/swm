import Darwin
import Testing

@testable import SwmLib

@Suite("UnixSocket")
struct UnixSocketTests {
  @Test("filePath: uses uid")
  func filePathUsesUID() {
    #expect(UnixSocket.filePath().hasSuffix("swm_\(getuid()).sock"))
  }
}
