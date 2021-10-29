import swmlib
import XCTest

final class LockFileErrorTests: XCTestCase {
    func testUserEnvVarMissingError() {
        do {
            throw LockFileError.userEnvVarMissing
        } catch {
            XCTAssertEqual("\(error)", "USER environment variable is not set")
        }
    }

    func testFailedToOpenFile() {
        do {
            throw LockFileError.failedToOpenFile
        } catch {
            XCTAssertEqual("\(error)", "failed to open lockfile")
        }
    }

    func testFailedToLockFile() {
        do {
            throw LockFileError.failedToLockFile
        } catch {
            XCTAssertEqual("\(error)", "failed to lock lockfile")
        }
    }
}
