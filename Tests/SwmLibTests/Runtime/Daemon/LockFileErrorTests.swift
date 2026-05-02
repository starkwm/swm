import Testing

@testable import SwmLib

@Suite("LockFileError")
struct LockFileErrorTests {
  @Test("description: describes failures")
  func descriptionDescribesFailures() {
    #expect(LockFileError.failedToOpenFile.description == "failed to open lockfile")
    #expect(LockFileError.failedToLockFile.description == "failed to lock lockfile")
  }
}
