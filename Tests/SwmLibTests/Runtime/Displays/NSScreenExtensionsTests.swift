import AppKit
import Testing

@testable import SwmLib

@Suite("NSScreenExtensions")
@MainActor
struct NSScreenExtensionsTests {
  @Test("uuid: is empty for a display that Core Graphics no longer knows")
  func uuidIsEmptyForADisplayThatCoreGraphicsNoLongerKnows() {
    #expect(DisconnectedTestScreen().uuid == "")
  }
}

private final class DisconnectedTestScreen: NSScreen {
  override var deviceDescription: [NSDeviceDescriptionKey: Any] {
    [NSDeviceDescriptionKey("NSScreenNumber"): NSNumber(value: UInt32(0xffff_fff0))]
  }
}
