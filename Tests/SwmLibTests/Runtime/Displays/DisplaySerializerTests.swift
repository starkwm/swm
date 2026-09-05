import AppKit
import Testing

@testable import SwmLib

@Suite("DisplaySerializer")
struct DisplaySerializerTests {
  @Test("all: retains screens while display Spaces are unavailable")
  @MainActor
  func allRetainsScreensWhileDisplaySpacesAreUnavailable() {
    let snapshot = QuerySnapshot(windows: Windows(workspace: Workspace()))
    snapshot.arrangedScreens = [QueryTestScreen(), QueryTestScreen()]
    snapshot.displaySpaces = [WindowServerDisplaySpaces(id: "disconnected-display", spaces: [10])]
    snapshot.spaces = [Space(id: 10)]
    snapshot.activeSpaceID = 10
    snapshot.currentSpaceByScreenID = [:]

    let displays = DisplaySerializer.all(snapshot: snapshot)

    #expect(displays.map(\.index) == [1, 2])
    #expect(displays.allSatisfy { $0.spaces.isEmpty })
    #expect(displays.allSatisfy { !$0.hasFocus })

    snapshot.displaySpaces = [WindowServerDisplaySpaces(id: "", spaces: [10])]
    snapshot.currentSpaceByScreenID = ["": 10]

    let resolvedDisplays = DisplaySerializer.all(snapshot: snapshot)

    #expect(resolvedDisplays.map(\.index) == [1, 2])
    #expect(resolvedDisplays.allSatisfy { $0.spaces == [0] })
    #expect(resolvedDisplays.allSatisfy { $0.hasFocus })
  }

  @Test("encode: uses kebab-case keys")
  func encodeUsesKebabCaseKeys() throws {
    let display = DisplaySerializer(
      id: 1,
      uuid: "display-uuid",
      index: 0,
      frame: FrameSerializer(.zero),
      spaces: [1],
      hasFocus: true
    )

    let object = try encodedObject(display)
    let spaces = try #require(object["spaces"] as? [Int])

    #expect(object["has-focus"] as? Bool == true)
    #expect(object["id"] as? Int == 1)
    #expect(object["uuid"] as? String == "display-uuid")
    #expect(spaces == [1])
  }
}

/// Screen geometry independent of the test host's connected displays.
private final class QueryTestScreen: NSScreen {
  override var deviceDescription: [NSDeviceDescriptionKey: Any] { [:] }

  override var frame: NSRect {
    NSRect(x: 0, y: 0, width: 1920, height: 1080)
  }
}
