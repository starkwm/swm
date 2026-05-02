import Testing

@testable import SwmLib

@Suite("UnixSocketError")
struct UnixSocketErrorTests {
  @Test("description: describes failures")
  func descriptionDescribesFailures() {
    #expect(
      UnixSocketError.frameTooLarge(1024).description
        == "IPC frame exceeded maximum size of 1024 bytes"
    )
    #expect(
      UnixSocketError.socketAlreadyInUse("/tmp/swm.sock").description
        == "socket is already in use at /tmp/swm.sock"
    )
  }
}
