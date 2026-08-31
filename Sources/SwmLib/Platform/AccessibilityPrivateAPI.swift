import ApplicationServices

// Private system functions imported from Accessibility.

/// Return the window ID for the given accessibility UI element.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("_AXUIElementGetWindow") @discardableResult
func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: inout UInt32) -> AXError

/// Create an accessibility element from a remote token.
// swift-format-ignore: AlwaysUseLowerCamelCase
@_silgen_name("_AXUIElementCreateWithRemoteToken") @discardableResult
func _AXUIElementCreateWithRemoteToken(_ data: CFData) -> Unmanaged<AXUIElement>?
