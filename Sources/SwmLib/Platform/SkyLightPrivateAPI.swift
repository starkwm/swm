import Carbon

// Private system functions imported from SkyLight.

/// Return display-space information.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSCopyManagedDisplaySpaces") @discardableResult
func SLSCopyManagedDisplaySpaces(_ connectionID: Int32) -> CFArray

/// Return the spaces that contain the given windows.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSCopySpacesForWindows") @discardableResult
func SLSCopySpacesForWindows(_ connectionID: Int32, _ mask: Int32, _ windows: CFArray) -> CFArray

/// Return windows on the given spaces.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSCopyWindowsWithOptionsAndTags") @discardableResult
func SLSCopyWindowsWithOptionsAndTags(
  _ connectionID: Int32,
  _ owner: UInt32,
  _ spaces: CFArray,
  _ options: UInt32,
  _ setTags: inout UInt64,
  _ clearTags: inout UInt64
) -> CFArray

/// Return the frontmost window and its owner at a screen point.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSFindWindowAndOwner") @discardableResult
func SLSFindWindowAndOwner(
  _ connectionID: Int32,
  _ windowID: Int32,
  _ options: Int32,
  _ relativeWindowID: Int32,
  _ screenPoint: inout CGPoint,
  _ windowPoint: inout CGPoint,
  _ foundWindowID: inout UInt32,
  _ foundWindowConnectionID: inout Int32
) -> OSStatus

/// Return the active space.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSGetActiveSpace") @discardableResult
func SLSGetActiveSpace(_ connectionID: Int32) -> UInt64

/// Return the connection ID for the given process serial number.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSGetConnectionIDForPSN") @discardableResult
func SLSGetConnectionIDForPSN(
  _ connectionID: Int32,
  _ psn: inout ProcessSerialNumber,
  _ processConnnectionID: inout Int32
) -> CGError

/// Return the main connection ID.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSMainConnectionID") @discardableResult
func SLSMainConnectionID() -> Int32

/// Return the current space for the given screen.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSManagedDisplayGetCurrentSpace") @discardableResult
func SLSManagedDisplayGetCurrentSpace(_ connectionID: Int32, _ screenID: CFString) -> UInt64

/// Return the type of space.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSSpaceGetType") @discardableResult
func SLSSpaceGetType(_ connectionID: Int32, _ spaceID: UInt64) -> Int32

/// Advance the given query iterator.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSWindowIteratorAdvance") @discardableResult
func SLSWindowIteratorAdvance(_ iterator: CFTypeRef) -> Bool

/// Return the window attributes for the given query iterator.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSWindowIteratorGetAttributes") @discardableResult
func SLSWindowIteratorGetAttributes(_ iterator: CFTypeRef) -> UInt64

/// Return the parent ID for the given query iterator.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSWindowIteratorGetParentID") @discardableResult
func SLSWindowIteratorGetParentID(_ iterator: CFTypeRef) -> UInt32

/// Return the window level for the given query iterator.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSWindowIteratorGetLevel") @discardableResult
func SLSWindowIteratorGetLevel(_ iterator: CFTypeRef) -> Int

/// Return the tags for the given query iterator.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSWindowIteratorGetTags") @discardableResult
func SLSWindowIteratorGetTags(_ iterator: CFTypeRef) -> UInt64

/// Return the window ID for the given query iterator.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSWindowIteratorGetWindowID") @discardableResult
func SLSWindowIteratorGetWindowID(_ iterator: CFTypeRef) -> UInt32

/// Return the iterator for the given query.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSWindowQueryResultCopyWindows") @discardableResult
func SLSWindowQueryResultCopyWindows(_ query: CFTypeRef) -> CFTypeRef

/// Query the given windows.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLSWindowQueryWindows") @discardableResult
func SLSWindowQueryWindows(_ connectionID: Int32, _ windows: CFArray, _ count: Int32) -> CFTypeRef

/// Post a private process event record.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("SLPSPostEventRecordTo") @discardableResult
func SLPSPostEventRecordTo(
  _ psn: inout ProcessSerialNumber,
  _ bytes: UnsafeMutablePointer<UInt8>
) -> CGError

/// Return the frontmost process serial number.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("_SLPSGetFrontProcess") @discardableResult
func _SLPSGetFrontProcess(_ psn: inout ProcessSerialNumber) -> OSStatus

/// Focus a process window using private WindowServer options.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("_SLPSSetFrontProcessWithOptions") @discardableResult
func _SLPSSetFrontProcessWithOptions(
  _ psn: inout ProcessSerialNumber,
  _ windowID: UInt32,
  _ options: UInt32
) -> CGError
