import XCTest

import class Foundation.Bundle

final class SwmTests: XCTestCase {
    func testLongVersionFlag() throws {
        let swmBinary = productsDirectory.appendingPathComponent("swm")

        let process = Process()
        process.executableURL = swmBinary
        process.arguments = ["--version"]

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)

        XCTAssertNotNil(output)
        XCTAssertTrue(output!.contains("swm version "))
        XCTAssertEqual(process.terminationStatus, 0)
    }

    func testShortVersionFlag() throws {
        let swmBinary = productsDirectory.appendingPathComponent("swm")

        let process = Process()
        process.executableURL = swmBinary
        process.arguments = ["-v"]

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)

        XCTAssertNotNil(output)
        XCTAssertTrue(output!.contains("swm version "))
        XCTAssertEqual(process.terminationStatus, 0)
    }

    /// Returns path to the built products directory.
    var productsDirectory: URL {
        for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
            return bundle.bundleURL.deletingLastPathComponent()
        }

        fatalError("couldn't find the products directory")
    }
}
