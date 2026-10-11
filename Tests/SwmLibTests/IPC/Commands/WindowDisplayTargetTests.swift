import AppKit
import Testing

@testable import SwmLib

@Suite("WindowDisplayTarget")
struct WindowDisplayTargetTests {
  @Test("screen: resolves one-based indexes from parsed targets", arguments: ["1", "2", "3"])
  @MainActor
  func screenResolvesOneBasedIndexesFromParsedTargets(argument: String) throws {
    let first = TargetTestScreen()
    let second = TargetTestScreen()
    let target = try #require(WindowDisplayTarget(argument: argument))
    let resolved = target.screen(from: first, screens: [first, second])
    switch argument {
    case "1": #expect(resolved === first)
    case "2": #expect(resolved === second)
    default: #expect(resolved == nil)
    }
    #expect(target.screen(from: first, screens: []) == nil)
  }

  @Test(
    "screen: resolves relative aliases on a single display",
    arguments: ["next", "prev", "previous"]
  )
  @MainActor
  func screenResolvesRelativeAliasesOnASingleDisplay(argument: String) throws {
    let screen = TargetTestScreen()
    let target = try #require(WindowDisplayTarget(argument: argument))
    #expect(target.screen(from: screen, screens: [screen]) === screen)
    #expect(target.screen(from: screen, screens: []) == nil)
  }
}

// A bare NSScreen can expose a display ID without a WindowServer UUID.
// Empty device metadata keeps these fixtures independent of connected displays.
private final class TargetTestScreen: NSScreen {
  override var deviceDescription: [NSDeviceDescriptionKey: Any] { [:] }
}
