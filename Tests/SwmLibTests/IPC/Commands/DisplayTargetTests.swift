import CoreGraphics
import Testing

@testable import SwmLib

@Suite("DisplayTarget")
struct DisplayTargetTests {
  // Three displays in arrangement order: left, centre, and one above the centre.
  private let displays = [
    DisplayCandidate(id: "left", frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080)),
    DisplayCandidate(id: "centre", frame: CGRect(x: 0, y: 0, width: 2560, height: 1440)),
    DisplayCandidate(id: "above", frame: CGRect(x: 320, y: -1080, width: 1920, height: 1080)),
  ]

  @Test(
    "displayID: resolves order targets from the source display, wrapping at the ends",
    arguments: [
      ("next", "centre", "above"),
      ("next", "above", "left"),
      ("prev", "left", "above"),
      ("previous", "centre", "left"),
      ("first", "above", "left"),
      ("last", "left", "above"),
      ("2", "above", "centre"),
    ]
  )
  func displayIDResolvesOrderTargets(argument: String, source: String, expected: String) throws {
    let target = try #require(DisplayTarget(argument: argument))

    #expect(resolve(target, from: source) == expected)
  }

  @Test(
    "displayID: resolves directions by display geometry",
    arguments: [
      ("left", "centre", "left"),
      ("up", "centre", "above"),
      ("down", "above", "centre"),
      ("right", "left", "centre"),
    ]
  )
  func displayIDResolvesDirections(argument: String, source: String, expected: String) throws {
    let target = try #require(DisplayTarget(argument: argument))

    #expect(resolve(target, from: source) == expected)
  }

  @Test("displayID: returns nil when no display matches")
  func displayIDReturnsNilWhenNoDisplayMatches() {
    #expect(resolve(.index(4), from: "centre") == nil)
    #expect(resolve(.direction(.right), from: "centre") == nil)
    #expect(resolve(.next, from: nil) == nil)
    #expect(resolve(.recent, from: "centre", recentID: nil) == nil)
    #expect(resolve(.recent, from: "centre", recentID: "disconnected") == nil)
    #expect(resolve(.mouse, from: "centre", mouseLocation: CGPoint(x: 0, y: 5000)) == nil)
    #expect(
      DisplayTarget.first.displayID(from: nil, displays: [], recentID: nil, mouseLocation: nil)
        == nil
    )
  }

  @Test("displayID: resolves the recent display and the display under the mouse")
  func displayIDResolvesRecentAndMouse() {
    #expect(resolve(.recent, from: "centre", recentID: "left") == "left")
    #expect(resolve(.mouse, from: "centre", mouseLocation: CGPoint(x: -10, y: 10)) == "left")
    #expect(resolve(.mouse, from: "left", mouseLocation: CGPoint(x: 400, y: -10)) == "above")
  }

  @Test("init: rejects unknown and non-positive targets", arguments: ["0", "-1", "north", ""])
  func initRejectsUnknownAndNonPositiveTargets(argument: String) {
    #expect(DisplayTarget(argument: argument) == nil)
  }

  private func resolve(
    _ target: DisplayTarget,
    from source: String?,
    recentID: String? = nil,
    mouseLocation: CGPoint? = nil
  ) -> String? {
    target.displayID(
      from: source,
      displays: displays,
      recentID: recentID,
      mouseLocation: mouseLocation
    )
  }
}
