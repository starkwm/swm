import swmlib
import XCTest

final class DaemonErrorTests: XCTestCase {
    func testUserEnvVarMissingError() {
        do {
            throw DaemonError.userEnvVarMissing
        } catch {
            XCTAssertEqual("\(error)", "USER environment variable is not set")
        }
    }
}
