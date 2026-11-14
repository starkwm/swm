import AppKit
import Testing

@testable import SwmLib

@Suite("NSScreen extensions")
@MainActor
struct NSScreenExtensionsTests {
  @Test("uuid: is empty for a display that Core Graphics no longer knows")
  func uuidIsEmptyForADisplayThatCoreGraphicsNoLongerKnows() {
    #expect(DisconnectedTestScreen().uuid == "")
  }
}

/// Screen whose display ID has no Core Graphics display, as during a disconnect.
private final class DisconnectedTestScreen: NSScreen {
  override var deviceDescription: [NSDeviceDescriptionKey: Any] {
    [NSDeviceDescriptionKey("NSScreenNumber"): NSNumber(value: UInt32(0xffff_fff0))]
  }
}
