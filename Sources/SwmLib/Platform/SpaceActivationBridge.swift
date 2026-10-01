import AppKit
import ObjectiveC

/// Submits the native operations needed to make a Desktop visible on its managed display.
@MainActor
enum SpaceActivationBridge {
  private typealias SpacesInitializer =
    @convention(c) (UnsafeMutableRawPointer, Selector, NSArray) -> Unmanaged<AnyObject>?
  private typealias CurrentInitializer =
    @convention(c) (UnsafeMutableRawPointer, Selector, NSString, UInt64) -> Unmanaged<AnyObject>?
  private typealias Perform = @convention(c) (AnyObject, Selector) -> Void

  private enum Arguments {
    case spaces([UInt64])
    case current(displayID: String, spaceID: UInt64)
  }

  /// Owns one SkyLight object and validates its methods before invoking them from Swift.
  private struct Operation {
    private static let performSelector = NSSelectorFromString("performWithWMBridgeDelegate")

    private static func method(
      in operationClass: AnyClass,
      selector: Selector,
      returning returnType: String,
      arguments argumentTypes: [String]
    ) throws -> Method {
      guard let method = class_getInstanceMethod(operationClass, selector),
        method_getNumberOfArguments(method) == argumentTypes.count + 2
      else {
        throw SpaceActivationBridgeError.unavailable
      }

      let result = method_copyReturnType(method)
      defer { free(result) }

      guard String(cString: result) == returnType else {
        throw SpaceActivationBridgeError.unavailable
      }

      for (index, expectedType) in argumentTypes.enumerated() {
        guard let argument = method_copyArgumentType(method, UInt32(index + 2)) else {
          throw SpaceActivationBridgeError.unavailable
        }
        defer { free(argument) }

        guard String(cString: argument) == expectedType else {
          throw SpaceActivationBridgeError.unavailable
        }
      }

      return method
    }

    private let object: AnyObject
    private let performMethod: Method

    init(_ arguments: Arguments, operationClass: AnyClass?) throws {
      guard let operationClass else { throw SpaceActivationBridgeError.unavailable }

      let (initializerName, argumentTypes) =
        switch arguments {
        case .spaces: ("initWithSpaces:", ["@"])
        case .current: ("initWithDisplayIdentifier:spaceID:", ["@", "Q"])
        }
      let selector = NSSelectorFromString(initializerName)
      let initializer = try Self.method(
        in: operationClass,
        selector: selector,
        returning: "@",
        arguments: argumentTypes
      )
      performMethod = try Self.method(
        in: operationClass,
        selector: Self.performSelector,
        returning: "v",
        arguments: []
      )

      guard let allocation = (operationClass as AnyObject).perform(NSSelectorFromString("alloc"))
      else {
        throw SpaceActivationBridgeError.creationFailed
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
        let initialize = unsafeBitCast(implementation, to: CurrentInitializer.self)
        initialized = initialize(allocation.toOpaque(), selector, displayID as NSString, spaceID)
      }

      guard let initialized else {
        throw SpaceActivationBridgeError.creationFailed
      }

      // Consume the owned alloc/init result once, as in WindowSpaceBridge.
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
}

enum SpaceActivationBridgeError: Error, Equatable, CustomStringConvertible {
  case unavailable
  case creationFailed

  var description: String {
    switch self {
    case .unavailable:
      return "Space activation is unavailable on this macOS version"
    case .creationFailed:
      return "could not create the Space activation operations"
    }
  }
}
