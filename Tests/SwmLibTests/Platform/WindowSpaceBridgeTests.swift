import AppKit
import Testing

@testable import SwmLib

@Suite("WindowSpaceBridge", .serialized)
@MainActor
struct WindowSpaceBridgeTests {
  @Test("move: invokes the Objective-C initializer and perform method with correct arguments")
  func invocation() throws {
    TestSpaceOperation.receivedWindows = nil
    TestSpaceOperation.receivedSpaceID = nil
    TestSpaceOperation.releasedCount = 0

    try WindowSpaceBridge.move(
      windowID: 42,
      to: 123_456_789_012,
      operationClass: TestSpaceOperation.self
    )

    #expect(TestSpaceOperation.receivedWindows == [42])
    #expect(TestSpaceOperation.receivedSpaceID == 123_456_789_012)
    #expect(TestSpaceOperation.releasedCount == 1)
  }

  @Test("move: reports missing classes and selectors before invocation")
  func unavailable() {
    for operationClass: AnyClass? in [nil, NSObject.self] {
      #expect(throws: WindowSpaceBridgeError.unavailable) {
        try WindowSpaceBridge.move(windowID: 42, to: 33, operationClass: operationClass)
      }
    }
  }
}

@objc(SwmTestSpaceOperation)
@MainActor
private final class TestSpaceOperation: NSObject {
  static var receivedWindows: [UInt32]?
  static var receivedSpaceID: UInt64?
  static var releasedCount = 0

  private let windows: NSArray
  private let spaceID: UInt64

  @objc(initWithWindows:spaceID:)
  init(windows: NSArray, spaceID: UInt64) {
    self.windows = windows
    self.spaceID = spaceID

    super.init()
  }

  isolated deinit { Self.releasedCount += 1 }

  @objc func performWithWMBridgeDelegate() {
    Self.receivedWindows = windows.compactMap { ($0 as? NSNumber)?.uint32Value }
    Self.receivedSpaceID = spaceID
  }
}
