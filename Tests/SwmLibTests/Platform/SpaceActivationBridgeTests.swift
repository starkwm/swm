import AppKit
import Testing

@testable import SwmLib

@Suite("SpaceActivationBridge", .serialized)
@MainActor
struct SpaceActivationBridgeTests {
  @Test("activate: shows, hides, then sets current with full-width IDs and owned objects")
  func invocation() throws {
    ActivationCalls.values = []
    ActivationCalls.releasedCount = 0

    try activate()

    #expect(
      ActivationCalls.values == [
        .spaces([123_456_789_012]), .spaces([11, 33]), .current("Main", 123_456_789_012),
      ]
    )
    #expect(ActivationCalls.releasedCount == 3)
  }

  @Test("activate: missing classes and selectors do not submit any operations")
  func unavailable() {
    for operationClass: AnyClass? in [nil, NSObject.self] {
      ActivationCalls.values = []
      #expect(throws: SpaceActivationBridgeError.unavailable) {
        try activate(hideClass: operationClass)
      }
      #expect(ActivationCalls.values.isEmpty)
      #expect(throws: SpaceActivationBridgeError.unavailable) {
        try activate(currentClass: operationClass)
      }
      #expect(ActivationCalls.values.isEmpty)
    }
  }

  @Test("activate: rejects changed argument and return types despite matching argument counts")
  func changedABI() {
    for operationClass: AnyClass in [WrongActivationArgument.self, WrongActivationReturn.self] {
      ActivationCalls.values = []
      #expect(throws: SpaceActivationBridgeError.unavailable) {
        try activate(hideClass: operationClass)
      }
      #expect(ActivationCalls.values.isEmpty)
    }
  }

  @Test("activate: a failed initializer prevents partial submission")
  func failedCreation() {
    ActivationCalls.values = []
    #expect(throws: SpaceActivationBridgeError.creationFailed) {
      try activate(hideClass: FailedActivationOperation.self)
    }
    #expect(ActivationCalls.values.isEmpty)
  }

  private func activate(
    hideClass: AnyClass? = TestActivationSpacesOperation.self,
    currentClass: AnyClass? = TestActivationCurrentOperation.self
  ) throws {
    try SpaceActivationBridge.activate(
      spaceID: 123_456_789_012,
      displayID: "Main",
      hiding: [11, 33],
      showClass: TestActivationSpacesOperation.self,
      hideClass: hideClass,
      currentClass: currentClass
    )
  }
}

private enum ActivationCall: Equatable {
  case spaces([UInt64])
  case current(String, UInt64)
}

@MainActor
private enum ActivationCalls {
  static var values: [ActivationCall] = []
  static var releasedCount = 0
}

@objc(SwmTestActivationSpacesOperation)
@MainActor
private final class TestActivationSpacesOperation: NSObject {
  private let spaces: NSArray

  @objc(initWithSpaces:)
  init(spaces: NSArray) {
    self.spaces = spaces
    super.init()
  }

  isolated deinit { ActivationCalls.releasedCount += 1 }

  @objc func performWithWMBridgeDelegate() {
    ActivationCalls.values.append(.spaces(spaces.compactMap { ($0 as? NSNumber)?.uint64Value }))
  }
}

@objc(SwmTestActivationCurrentOperation)
@MainActor
private final class TestActivationCurrentOperation: NSObject {
  private let displayID: NSString
  private let spaceID: UInt64

  @objc(initWithDisplayIdentifier:spaceID:)
  init(displayID: NSString, spaceID: UInt64) {
    self.displayID = displayID
    self.spaceID = spaceID
    super.init()
  }

  isolated deinit { ActivationCalls.releasedCount += 1 }

  @objc func performWithWMBridgeDelegate() {
    ActivationCalls.values.append(.current(displayID as String, spaceID))
  }
}

@objc(SwmWrongActivationArgument)
private final class WrongActivationArgument: NSObject {
  @objc(initWithSpaces:)
  init(spaces: UInt64) { super.init() }

  @objc func performWithWMBridgeDelegate() {}
}

@objc(SwmWrongActivationReturn)
private final class WrongActivationReturn: NSObject {
  @objc(initWithSpaces:)
  init(spaces: NSArray) { super.init() }

  @objc func performWithWMBridgeDelegate() -> Int32 { 0 }
}

@objc(SwmFailedActivationOperation)
private final class FailedActivationOperation: NSObject {
  @objc(initWithSpaces:)
  init?(spaces: NSArray) { return nil }

  @objc func performWithWMBridgeDelegate() {}
}
