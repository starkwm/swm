import AppKit
import ObjectiveC

/// Submits native Space operations through SkyLight's WindowManager bridge without Dock injection.
@MainActor
enum SpaceBridge {
  private typealias SpacesInitializer =
    @convention(c) (UnsafeMutableRawPointer, Selector, NSArray) -> Unmanaged<AnyObject>?
  private typealias ObjectAndSpaceInitializer =
    @convention(c) (UnsafeMutableRawPointer, Selector, AnyObject, UInt64) -> Unmanaged<AnyObject>?
  private typealias Perform = @convention(c) (AnyObject, Selector) -> Void

  private enum Arguments {
    case spaces([UInt64])
    case current(displayID: String, spaceID: UInt64)
    case windows([CGWindowID], spaceID: UInt64)
  }

  /// Owns one SkyLight object and validates its methods before invoking them from Swift.
  private struct Operation {
    private static let performSelector = NSSelectorFromString("performWithWMBridgeDelegate")

    private static func method(
      in operationClass: AnyClass,
      selector: Selector,
      returning returnType: String,
      arguments argumentTypes: [String],
      feature: SpaceBridgeError.Feature
    ) throws -> Method {
      guard let method = class_getInstanceMethod(operationClass, selector),
        method_getNumberOfArguments(method) == argumentTypes.count + 2
      else {
        throw SpaceBridgeError.unavailable(feature)
      }

      let result = method_copyReturnType(method)
      defer { free(result) }

      guard String(cString: result) == returnType else {
        throw SpaceBridgeError.unavailable(feature)
      }

      for (index, expectedType) in argumentTypes.enumerated() {
        guard let argument = method_copyArgumentType(method, UInt32(index + 2)) else {
          throw SpaceBridgeError.unavailable(feature)
        }
        defer { free(argument) }

        guard String(cString: argument) == expectedType else {
          throw SpaceBridgeError.unavailable(feature)
        }
      }

      return method
    }

    private let object: AnyObject
    private let performMethod: Method

    init(_ arguments: Arguments, operationClass: AnyClass?) throws {
      let (initializerName, argumentTypes, feature): (String, [String], SpaceBridgeError.Feature) =
        switch arguments {
        case .spaces: ("initWithSpaces:", ["@"], .activation)
        case .current: ("initWithDisplayIdentifier:spaceID:", ["@", "Q"], .activation)
        case .windows: ("initWithWindows:spaceID:", ["@", "Q"], .windowMove)
        }
      guard let operationClass else { throw SpaceBridgeError.unavailable(feature) }

      let selector = NSSelectorFromString(initializerName)
      let initializer = try Self.method(
        in: operationClass,
        selector: selector,
        returning: "@",
        arguments: argumentTypes,
        feature: feature
      )
      performMethod = try Self.method(
        in: operationClass,
        selector: Self.performSelector,
        returning: "v",
        arguments: [],
        feature: feature
      )

      guard let allocation = (operationClass as AnyObject).perform(NSSelectorFromString("alloc"))
      else {
        throw SpaceBridgeError.creationFailed(feature)
      }

      let implementation = method_getImplementation(initializer)
      let initialized: Unmanaged<AnyObject>?
      switch arguments {
      case .spaces(let spaceIDs):
        let initialize = unsafeBitCast(implementation, to: SpacesInitializer.self)
        initialized = initialize(
          allocation.toOpaque(),
          selector,
          spaceIDs.map { NSNumber(value: $0) } as NSArray
        )
      case .current(let displayID, let spaceID):
        let initialize = unsafeBitCast(implementation, to: ObjectAndSpaceInitializer.self)
        initialized = initialize(allocation.toOpaque(), selector, displayID as NSString, spaceID)
      case .windows(let windowIDs, let spaceID):
        let initialize = unsafeBitCast(implementation, to: ObjectAndSpaceInitializer.self)
        initialized = initialize(
          allocation.toOpaque(),
          selector,
          windowIDs.map { NSNumber(value: $0) } as NSArray,
          spaceID
        )
      }

      guard let initialized else {
        throw SpaceBridgeError.creationFailed(feature)
      }

      // alloc/init returns an owned object. Consume that ownership once after initialization.
      object = initialized.takeRetainedValue()
    }

    func perform() {
      let perform = unsafeBitCast(method_getImplementation(performMethod), to: Perform.self)
      perform(object, Self.performSelector)
    }
  }

  /// Construct every operation before submitting any asynchronous writes.
  static func activate(
    spaceID: UInt64,
    displayID: String,
    hiding spaceIDs: [UInt64],
    showClass: AnyClass? = NSClassFromString("SLSBridgedShowSpacesOperation"),
    hideClass: AnyClass? = NSClassFromString("SLSBridgedHideSpacesOperation"),
    currentClass: AnyClass? = NSClassFromString("SLSBridgedManagedDisplaySetCurrentSpaceOperation")
  ) throws {
    let show = try Operation(.spaces([spaceID]), operationClass: showClass)
    let hide = try Operation(.spaces(spaceIDs), operationClass: hideClass)
    let current = try Operation(
      .current(displayID: displayID, spaceID: spaceID),
      operationClass: currentClass
    )

    show.perform()
    hide.perform()
    current.perform()
  }

  /// Submission is asynchronous; callers must verify the window's Space membership.
  static func move(
    windowID: CGWindowID,
    to spaceID: UInt64,
    operationClass: AnyClass? = NSClassFromString("SLSBridgedMoveWindowsToManagedSpaceOperation")
  ) throws {
    try Operation(.windows([windowID], spaceID: spaceID), operationClass: operationClass).perform()
  }
}

enum SpaceBridgeError: Error, Equatable, CustomStringConvertible {
  enum Feature {
    case activation
    case windowMove
  }

  case unavailable(Feature)
  case creationFailed(Feature)

  var description: String {
    switch self {
    case .unavailable(.activation):
      return "Space activation is unavailable on this macOS version"
    case .unavailable(.windowMove):
      return "window-to-Space movement is unavailable on this macOS version"
    case .creationFailed(.activation):
      return "could not create the Space activation operations"
    case .creationFailed(.windowMove):
      return "could not create the window-to-Space operation"
    }
  }
}
