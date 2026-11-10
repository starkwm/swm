import AppKit
import Testing

@testable import SwmLib

@Suite("SpaceBridge", .serialized)
@MainActor
struct SpaceBridgeTests {
  @Test("activate: shows, hides, then sets current with full-width IDs and owned objects")
  func activateShowsHidesThenSetsCurrentWithFullWidthIDsAndOwnedObjects() throws {
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
  func activateMissingClassesAndSelectorsDoNotSubmitAnyOperations() {
    for operationClass: AnyClass? in [nil, NSObject.self] {
      ActivationCalls.values = []
      #expect(throws: SpaceBridgeError.unavailable(.activation)) {
        try activate(hideClass: operationClass)
      }
      #expect(ActivationCalls.values.isEmpty)
      #expect(throws: SpaceBridgeError.unavailable(.activation)) {
        try activate(currentClass: operationClass)
      }
      #expect(ActivationCalls.values.isEmpty)
    }
  }

  @Test("activate: rejects changed argument and return types despite matching argument counts")
  func activateRejectsChangedArgumentAndReturnTypesDespiteMatchingArgumentCounts() {
    for operationClass: AnyClass in [WrongActivationArgument.self, WrongActivationReturn.self] {
      ActivationCalls.values = []
      #expect(throws: SpaceBridgeError.unavailable(.activation)) {
        try activate(hideClass: operationClass)
      }
      #expect(ActivationCalls.values.isEmpty)
    }
  }

  @Test("activate: a failed initializer prevents partial submission")
  func activateAFailedInitializerPreventsPartialSubmission() {
    ActivationCalls.values = []
    #expect(throws: SpaceBridgeError.creationFailed(.activation)) {
      try activate(hideClass: FailedActivationOperation.self)
    }
    #expect(ActivationCalls.values.isEmpty)
  }

  @Test("move: invokes the Objective-C initializer and perform method with correct arguments")
  func moveInvokesTheObjectiveCInitializerAndPerformMethodWithCorrectArguments() throws {
    TestSpaceOperation.receivedWindows = nil
    TestSpaceOperation.receivedSpaceID = nil
    TestSpaceOperation.releasedCount = 0

    try SpaceBridge.move(
      windowID: 42,
      to: 123_456_789_012,
      operationClass: TestSpaceOperation.self
    )

    #expect(TestSpaceOperation.receivedWindows == [42])
    #expect(TestSpaceOperation.receivedSpaceID == 123_456_789_012)
    #expect(TestSpaceOperation.releasedCount == 1)
  }

  @Test("move: reports missing classes and selectors before invocation")
  func moveReportsMissingClassesAndSelectorsBeforeInvocation() {
    for operationClass: AnyClass? in [nil, NSObject.self] {
      #expect(throws: SpaceBridgeError.unavailable(.windowMove)) {
        try SpaceBridge.move(windowID: 42, to: 33, operationClass: operationClass)
      }
    }
  }

  private func activate(
    hideClass: AnyClass? = TestActivationSpacesOperation.self,
    currentClass: AnyClass? = TestActivationCurrentOperation.self
  ) throws {
    try SpaceBridge.activate(
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
