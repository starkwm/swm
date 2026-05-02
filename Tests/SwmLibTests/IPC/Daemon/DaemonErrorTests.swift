import Testing

@testable import SwmLib

@Suite("DaemonError")
struct DaemonErrorTests {
  @Test("description: describes failures")
  func descriptionDescribesFailures() {
    #expect(
      DaemonError.unableToPrepareSocket("busy").description
        == "unable to prepare listening socket - busy"
    )
    #expect(DaemonError.unableToCreateSocket.description == "unable to create listening socket")
    #expect(DaemonError.unableToUnwrapSocket.description == "unable to unwrap listening socket")
    #expect(
      DaemonError.unableToListenOnSocket.description == "unable to listen on listening socket"
    )
  }
}
