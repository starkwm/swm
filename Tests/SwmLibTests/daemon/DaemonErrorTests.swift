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

    func testUnableToCreateSocketError() {
        do {
            throw DaemonError.unableToCreateSocket
        } catch {
            XCTAssertEqual("\(error)", "unable to create listening socket")
        }
    }

    func testUnableToUnwrapSocketError() {
        do {
            throw DaemonError.unableToUnwrapSocket
        } catch {
            XCTAssertEqual("\(error)", "unable to unwrap listening socket")
        }
    }

    func testUnableToListenOnSocketError() {
        do {
            throw DaemonError.unableToListenOnSocket
        } catch {
            XCTAssertEqual("\(error)", "unable to listen on listening socket")
        }
    }
}
