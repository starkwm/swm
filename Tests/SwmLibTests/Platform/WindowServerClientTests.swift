import Testing

@testable import SwmLib

@Suite("WindowServerClient")
struct WindowServerClientTests {
  @Test("windowIdentifiers: returns no windows when WindowServer has none for the connection")
  func windowIdentifiersReturnsNoWindowsWhenWindowServerHasNoneForTheConnection() {
    let client = WindowServerClient.shared

    #expect(client.windowIdentifiers(applicationConnectionID: 0, spaceIDs: [1]).isEmpty)
    #expect(client.windowIdentifiers(applicationConnectionID: .max, spaceIDs: []).isEmpty)
  }
}
