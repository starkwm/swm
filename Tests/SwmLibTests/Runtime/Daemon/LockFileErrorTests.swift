import Testing

@testable import SwmLib

@Suite("LockFileError")
struct LockFileErrorTests {
  @Test("lock file errors describe failures")
  func lockFileErrorsDescribeFailures() {
    #expect(LockFileError.failedToOpenFile.description == "failed to open lockfile")
    #expect(LockFileError.failedToLockFile.description == "failed to lock lockfile")
  }
}
