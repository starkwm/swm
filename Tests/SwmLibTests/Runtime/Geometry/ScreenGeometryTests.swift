import CoreGraphics
import Testing

@testable import SwmLib

@Suite("ScreenGeometry")
struct ScreenGeometryTests {
  @Test(
    "accessibilityFrame: converts every display relative to the primary origin",
    arguments: [
      (CGRect(x: 0, y: 0, width: 1440, height: 900), CGRect(x: 0, y: 0, width: 1440, height: 900)),
      (
        CGRect(x: 0, y: 900, width: 1920, height: 1080),
        CGRect(x: 0, y: -1080, width: 1920, height: 1080)
      ),
      (
        CGRect(x: 200, y: -1080, width: 1920, height: 1080),
        CGRect(x: 200, y: 900, width: 1920, height: 1080)
      ),
      (
        CGRect(x: -1920, y: -180, width: 1920, height: 1080),
        CGRect(x: -1920, y: 0, width: 1920, height: 1080)
      ),
      (
        CGRect(x: 1440, y: -180, width: 1920, height: 1080),
        CGRect(x: 1440, y: 0, width: 1920, height: 1080)
      ),
    ]
  )
  func accessibilityFrameConvertsEveryDisplayRelativeToThePrimaryOrigin(
    frame: CGRect,
    expected: CGRect
  ) {
    let primary = CGRect(x: 0, y: 0, width: 1440, height: 900)
    #expect(ScreenGeometry.accessibilityFrame(frame, primaryFrame: primary) == expected)
    // A 24-point menu bar, 60-point bottom Dock, and 8-point left inset.
    let visible = CGRect(
      x: frame.minX + 8,
      y: frame.minY + 60,
      width: frame.width - 8,
      height: frame.height - 84
    )
    let expectedVisible = CGRect(
      x: expected.minX + 8,
      y: expected.minY + 24,
      width: expected.width - 8,
      height: expected.height - 84
    )
    #expect(ScreenGeometry.accessibilityFrame(visible, primaryFrame: primary) == expectedVisible)
  }

  @Test(
    "visibleFrame: gives an automatically hidden Dock's edge back and keeps the menu bar",
    arguments: [
      (DockEdge?.none, CGRect(x: 0, y: 53, width: 1710, height: 1021)),
      (DockEdge.bottom, CGRect(x: 0, y: 0, width: 1710, height: 1074)),
      (DockEdge.left, CGRect(x: 0, y: 53, width: 1710, height: 1021)),
    ]
  )
  func visibleFrameGivesAnAutomaticallyHiddenDocksEdgeBack(edge: DockEdge?, expected: CGRect) {
    let frame = CGRect(x: 0, y: 0, width: 1710, height: 1112)
    let withDock = CGRect(x: 0, y: 53, width: 1710, height: 1021)

    #expect(ScreenGeometry.visibleFrame(withDock, in: frame, hiddenDockEdge: edge) == expected)
  }

  @Test("visibleFrame: restores side Docks on screens away from the origin")
  func visibleFrameRestoresSideDocksOnScreensAwayFromTheOrigin() {
    let frame = CGRect(x: 1710, y: -200, width: 1920, height: 1080)

    #expect(
      ScreenGeometry.visibleFrame(
        CGRect(x: 1790, y: -200, width: 1840, height: 1055),
        in: frame,
        hiddenDockEdge: .left
      ) == CGRect(x: 1710, y: -200, width: 1920, height: 1055)
    )
    #expect(
      ScreenGeometry.visibleFrame(
        CGRect(x: 1710, y: -200, width: 1840, height: 1055),
        in: frame,
        hiddenDockEdge: .right
      ) == CGRect(x: 1710, y: -200, width: 1920, height: 1055)
    )
  }
}
