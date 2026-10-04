import CoreGraphics
import Testing

@testable import SwmLib

@Suite("ScrollingWindowPlacement")
struct ScrollingWindowPlacementTests {
  @Test("place: retains partial windows and parks distant columns with a sliver")
  func singleDisplay() throws {
    let display = SpaceTopologyDisplay(visibleFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800))
    let frames: [CGWindowID: CGRect] = [
      1: CGRect(x: -100, y: 0, width: 500, height: 800),
      2: CGRect(x: 2_000, y: 0, width: 500, height: 800),
    ]

    let result = ScrollingWindowPlacement().place(frames, on: display, otherDisplays: [])
    guard case .frames(let physical, let parked) = result else {
      Issue.record("Expected physical placement")
      return
    }

    #expect(physical[1] == frames[1])
    #expect(physical[2]?.minX == 999)
    #expect(physical[2]?.intersection(display.visibleFrame).width == 1)
    #expect(parked == [2])
  }

  @Test("place: parks crossing columns away from horizontally adjacent displays")
  func horizontalDisplays() {
    let owner = SpaceTopologyDisplay(visibleFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800))
    let neighbors = [
      SpaceTopologyDisplay(visibleFrame: CGRect(x: -1_000, y: 0, width: 1_000, height: 800)),
      SpaceTopologyDisplay(visibleFrame: CGRect(x: 1_000, y: 0, width: 1_000, height: 800)),
    ]
    let frames: [CGWindowID: CGRect] = [
      1: CGRect(x: 0, y: 0, width: 500, height: 800),
      2: CGRect(x: 800, y: 0, width: 500, height: 800),
      3: CGRect(x: 1_500, y: 0, width: 500, height: 800),
    ]

    let result = ScrollingWindowPlacement().place(frames, on: owner, otherDisplays: neighbors)
    guard case .frames(let physical, let parked) = result else {
      Issue.record("Expected physical placement")
      return
    }

    #expect(physical[1] == frames[1])
    #expect(parked == [2, 3])
    for frame in physical.values {
      #expect(!frame.intersection(owner.visibleFrame).isNull)
      for neighbor in neighbors {
        let overlap = frame.intersection(neighbor.visibleFrame)
        #expect(overlap.isNull || overlap.width == 0 || overlap.height == 0)
      }
    }
  }

  @Test("place: uses full display bounds instead of the Dock edge")
  func fullBounds() {
    let owner = SpaceTopologyDisplay(
      visibleFrame: CGRect(x: 0, y: 25, width: 1_000, height: 725),
      frame: CGRect(x: 0, y: 0, width: 1_000, height: 800)
    )
    let neighbors = [
      SpaceTopologyDisplay(visibleFrame: CGRect(x: -1_000, y: 0, width: 1_000, height: 800)),
      SpaceTopologyDisplay(visibleFrame: CGRect(x: 1_000, y: 0, width: 1_000, height: 800)),
    ]

    let result = ScrollingWindowPlacement().place(
      [1: CGRect(x: 1_500, y: 25, width: 500, height: 725)],
      on: owner,
      otherDisplays: neighbors
    )
    guard case .frames(let frames, _) = result else {
      Issue.record("Expected physical placement")
      return
    }

    #expect(frames[1]?.minY == 799)
  }

  @Test("place: refuses parking when every edge intersects another display")
  func enclosedDisplay() {
    let owner = SpaceTopologyDisplay(visibleFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800))
    let neighbors = [
      CGRect(x: -1_000, y: 0, width: 1_000, height: 800),
      CGRect(x: 1_000, y: 0, width: 1_000, height: 800),
      CGRect(x: 0, y: -800, width: 1_000, height: 800),
      CGRect(x: 0, y: 800, width: 1_000, height: 800),
    ].map { SpaceTopologyDisplay(visibleFrame: $0) }

    let result = ScrollingWindowPlacement().place(
      [1: CGRect(x: 2_000, y: 0, width: 500, height: 800)],
      on: owner,
      otherDisplays: neighbors
    )

    guard case .insufficientSpace(.scrollingParking) = result else {
      Issue.record("Expected a parking constraint")
      return
    }
  }
}
