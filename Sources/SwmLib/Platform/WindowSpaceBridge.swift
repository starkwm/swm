import AppKit
import ObjectiveC

/// Submits window moves through SkyLight's WindowManager bridge without Dock injection.
@MainActor
enum WindowSpaceBridge {
  private typealias Initializer =
    @convention(c) (
      UnsafeMutableRawPointer, Selector, NSArray, UInt64
    ) -> Unmanaged<AnyObject>?
  private typealias Perform = @convention(c) (AnyObject, Selector) -> Void

  /// Submission is asynchronous; callers must verify the window's Space membership.
  static func move(
    windowID: CGWindowID,
    to spaceID: UInt64,
    operationClass: AnyClass? = NSClassFromString("SLSBridgedMoveWindowsToManagedSpaceOperation")
  ) throws {
    let initializerSelector = NSSelectorFromString("initWithWindows:spaceID:")
    let performSelector = NSSelectorFromString("performWithWMBridgeDelegate")

    guard
      let operationClass,
      let initializerMethod = class_getInstanceMethod(operationClass, initializerSelector),
      let performMethod = class_getInstanceMethod(operationClass, performSelector),
      method_getNumberOfArguments(initializerMethod) == 4,
      method_getNumberOfArguments(performMethod) == 2
    else {
      throw WindowSpaceBridgeError.unavailable
    }

    guard let allocation = (operationClass as AnyObject).perform(NSSelectorFromString("alloc"))
    else {
      throw WindowSpaceBridgeError.creationFailed
    }

    let initialize = unsafeBitCast(
      method_getImplementation(initializerMethod),
      to: Initializer.self
    )

    // alloc/init returns an owned object. Consume that ownership once after initialization.
    guard
      let operation = initialize(
        allocation.toOpaque(),
        initializerSelector,
        [NSNumber(value: windowID)] as NSArray,
        spaceID
      )?.takeRetainedValue()
    else {
      throw WindowSpaceBridgeError.creationFailed
    }

    let perform = unsafeBitCast(method_getImplementation(performMethod), to: Perform.self)

    perform(operation, performSelector)
  }
}

enum WindowSpaceBridgeError: Error, Equatable, CustomStringConvertible {
  case unavailable
  case creationFailed

  var description: String {
    switch self {
    case .unavailable:
      return "window-to-Space movement is unavailable on this macOS version"
    case .creationFailed:
      return "could not create the window-to-Space operation"
    }
  }
}
