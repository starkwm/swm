import XCTest
import swmlib

final class LockFileTests: XCTestCase {
    func testAcquire() {
        XCTAssertNoThrow(try LockFile.acquire())
    }

    func testAcquireNoUserEnvVar() {
        unsetenv("USER")

        XCTAssertThrowsError(try LockFile.acquire()) { error in
            XCTAssertEqual(error as? LockFileError, LockFileError.userEnvVarMissing)
        }
    }
}
